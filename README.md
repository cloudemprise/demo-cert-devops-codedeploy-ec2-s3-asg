# demo-cert-devops-codedeploy-ec2-s3-asg

> The repository contains artifacts and reference material related to an AWS CodeDepoly deployment project and its auxiliary components. These components are used to perform a deployment of a sample application to instances designated within an EC2 AutoScaling Group. In particular, this project investigates the AutoScaling Lifecycle Hook that CodeDeploy uses to deploy a revision application to new instances during a scale-out event.

#### Overview

The artifacts within this repository illustrate how AWS CodeDeploy deploys a sample revision application from an S3 Bucket archive to an EC2 AutoScaling Group. This is achieved by way of an autoscaling lifecycle hook that interrupts the scale-out process so that a new revision application can be deployed before the new instance is included within an AutoScaling Group.

It elaborates on the notes given within the following documentation:

[Tutorial: Use CodeDeploy to deploy an application to an Amazon EC2 Auto Scaling group](https://docs.aws.amazon.com/codedeploy/latest/userguide/tutorials-auto-scaling-group.html)


#### Integrating CodeDeploy with S3

A revision is a version of the source files that CodeDeploy will deploy to your target instances or scripts that CodeDeploy will run on these instances. Once you have added an [AppSpec](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-specification-files.html) file to this revision, you can then upload this code bundle as an archive to an Amazon S3 bucket that is in the same region as the instances you wish to deploy to.







- AWS CodeDeploy - [Push a revision for CodeDeploy to Amazon S3](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-revisions-push.html)

- AWS DevOps Blog - [Automatically Deploy from Amazon S3 using AWS CodeDeploy](https://aws.amazon.com/blogs/devops/automatically-deploy-from-amazon-s3-using-aws-codedeploy/)





#### AWS CodeDeploy Agent

For type EC2/On-Premises deployments, the AWS CodeDeploy service requires that an agent be installed on the target instance. The CodeDeploy agent communicates outbound using HTTPS over port 443 and is not required for deployments that use the Amazon ECS or AWS Lambda compute platform. Log file can be found here: /var/log/aws/codedeploy-agent.

For the simplicity of convenience, this demonstration manually installs the agent via the Userdata Script facility of the Launch Template CloudFormation nested stack.

This agent could very well be be installed using AWS Systems Manager and is in fact the recommended method for installing and updating the CodeDeploy agent. There is a very handy AWS Systems Manager service integration that can set up installation and scheduled updates via the AWS Console when you manually create a Deployment Group. Don't forget to include the Managed Policy: AmazonSSMManagedInstanceCore within your service role.

---

Install the CodeDeploy agent by calling the create-association command from AWS Systems Manager with the tags that were added when the Amazon EC2 Auto Scaling group was created. 

```bash
aws ssm create-association \
  --name AWS-ConfigureAWSPackage \
  --targets Key=tag:Name,Values=CodeDeployDemo \
   --parameters action=Install, name=AWSCodeDeployAgent \
  --schedule-expression "cron(0 2 ? * SUN *)" 

```

This command creates an association in Systems Manager State Manager that will install the CodeDeploy agent on all instances in the Amazon EC2 Auto Scaling group and then attempt to update it at 2:00 every Sunday morning. 

For more information about the CodeDeploy agent, see Working with the CodeDeploy agent. For more information about Systems Manager, see What is AWS Systems Manager.



#### Infrastructure As Code

A stand-alone solution records the complete infrastructure definition and takes the form of nested AWS CloudFormation templates. These are provisioned via a bash script that orchestrate the creation of all the Cloud resource components required in this demonstration and comprise the following:


```bash

automation/
│
├── cfn-templates
│   │
│   ├── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-deploy.yaml....(DEPLOYMENT)
│   ├── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-ec2-alb.yaml...(APP LOADBALANCER)
│   ├── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-ec2-asg.yaml...(AUTOSCALING GROUP)
│   ├── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-ec2-tg.yaml....(LAUNCH TEMPLATE)
│   ├── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-iam.yaml.......(IAM ROLES)
│   ├── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-vpc-sg.yaml....(SECURITY GROUP)
│   ├── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-vpc.yaml.......(VPC)
│   └── demo-cert-devops-codedeploy-ec2-s3-asg-cfn.yaml...........(TOP LEVEL)
│
└── provision-infrastructure-cfn-templates.sh.....................(BASH SCRIPT)


```

---

### Autoscaling

CodeDeploy supports Amazon EC2 Auto Scaling

When new Amazon EC2 instances are launched as part of an Amazon EC2 Auto Scaling group, CodeDeploy can deploy your revisions to the new instances automatically.

Needs special IAM Instance profile / CodeDeploy Service Role.

Instead of designating a deployment group with tags just designate with an  Amazon EC2 Auto Scaling group name and service role.

#### Lifecycle Hook

In order for CodeDeploy to deploy your application revision to new EC2 instances during an Auto Scaling scale-out event, CodeDeploy uses an Auto Scaling lifecycle hook.

When you create or update a deployment group to include an Auto Scaling group, CodeDeploy accesses the Auto Scaling group using the CodeDeploy service role, and then installs a lifecycle hook in the Auto Scaling group.

##### Order of events in AWS CloudFormation cfn-init scripts

If you use cfn-init (or cloud-init) to run scripts on newly provisioned Linux-based instances, your deployments might fail unless you strictly control the order of events that occur after the instance starts.


##### Increase the number of Amazon EC2 instances in the Amazon EC2 Auto Scaling group

To scale out the number of Amazon EC2 instances in the Amazon EC2 Auto Scaling group

```bash

aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name CodeDeployDemo-AS-Group \
  --min-size 2 \
  --max-size 2 \
  --desired-capacity 2

```

Make sure the Amazon EC2 Auto Scaling group now has two Amazon EC2 instances. Call the describe-auto-scaling-groups command against CodeDeployDemo-AS-Group:

```bash

aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names CodeDeployDemo-AS-Group --query "AutoScalingGroups[0].Instances[*].[HealthStatus, LifecycleState]" --output text

```





---

### LoadBalancers

For in-place deployments:
During CodeDeploy deployments, a load balancer prevents internet traffic from being routed to instances when they are not ready, are currently being deployed to, or are no longer needed as part of an environment.



---



#### Reference:


- AWS CodeDeploy - [Integrating CodeDeploy with Amazon EC2 Auto Scaling](https://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-aws-auto-scaling.html).

- Amazon EC2 Auto Scaling - [Amazon EC2 Auto Scaling lifecycle hooks](https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html)

- AWS Command Line Interface - [deploy](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/index.html#cli-aws-deploy)

- AWS CloudFormation - [AWS CodeDeploy resource type reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_CodeDeploy.html)

- AWS CodeDeploy - [Push a revision for CodeDeploy to Amazon S3](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-revisions-push.html)

- AWS CodeDeploy - [Integrating CodeDeploy with Elastic Load Balancing](https://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-aws-elastic-load-balancing.html)

- AWS CodeDeploy - [Set up a load balancer in Elastic Load Balancing for CodeDeploy Amazon EC2 deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-groups-create-load-balancer.html)

Under the Hood: AWS CodeDeploy and Auto Scaling Integration 
https://aws.amazon.com/blogs/devops/under-the-hood-aws-codedeploy-and-auto-scaling-integration/

- AWS CodeDeploy - [How Amazon EC2 Auto Scaling works with CodeDeploy: Order of events in AWS CloudFormation cfn-init scripts](https://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-aws-auto-scaling.html#integrations-aws-auto-scaling-behaviors-event-order)


- AWS CodeDeploy - [Working with the CodeDeploy agent](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent.html)



#### Relevant APIs:

> ##### _AWS CodeDeploy_

> [create-application](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/create-application.html)

> [create-deployment-group](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/create-deployment-group.html)

> [create-deployment](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/create-deployment.html)

> [create-deployment-config](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/create-deployment-config.html)

> [get-deployment-instance](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/get-deployment-instance.html)

> [get-deployment-config](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/get-deployment-config.html)

--- 

> [push](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/push.html)


---

> ##### _Amazon EC2 Auto Scaling_

> [describe-lifecycle-hooks](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/describe-lifecycle-hooks.html)

aws autoscaling describe-auto-scaling-groups





- CreationPolicy attribute


Default credit specificationInfo
The default credit option for CPU usage of burstable performance instances, T2, T3, T3a and T4g. Here you can modify the specification.
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances-how-to.html
https://aws.amazon.com/ec2/spot/pricing/#Spot_Instance_Prices



Display a complete list of all available Public Parameter Amazon Linux AMIs
https://aws.amazon.com/blogs/compute/query-for-the-latest-amazon-linux-ami-ids-using-aws-systems-manager-parameter-store/
aws ssm get-parameters-by-path --path "/aws/service/ami-amazon-linux-latest" --region us-east-1

aws ssm get-parameters-by-path --path "/aws/service/ami-amazon-linux-latest" --query Parameters[].Name



Note that the Autoscaling Stack includes a Launch Template declaration. This is required since the Launch Template wait condition refers to the logical ID of the Autoscaling Group.


APIs

[set-instance-health](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/set-instance-health.html)

[describe-auto-scaling-groups](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/autoscaling/describe-auto-scaling-groups.html)





CloudFormation helper scripts reference
https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-helper-scripts-reference.html




# !! Note: for blue/green deployments, CloudFormation supports Lambda
# deployments ONLY - NOT EC2!! EC2 blue/green deployments conducted
# manually via Console only.
# For ECS blue/green deployments use AWS::CodeDeploy::BlueGreen hook


Note on ec2 blue/green deployment: did not use a lauchtemplate here since replacement instances 
would not have the CodeDeploy Agent installed on them as the lauchtemplate would only be used 
during infrastructure provisioning and not during blue/green deployment.