# demo-cert-devops-codedeploy-ec2-s3-asg

> This repository contains artifacts and reference material related to an AWS CodeDepoly deployment project and other accessory components. These components are used to perform a deployment of a sample application to instances designated within an Amazon EC2 Auto Scaling Group from an Amazon S3 Bucket. In particular, this project investigates the AutoScaling Lifecycle Hook that AWS CodeDeploy uses to deploy a revision application to new instances during a scale-out event.

#### Overview

The artifacts within this repository illustrate how AWS CodeDeploy deploys a sample revision application from an S3 Bucket archive to an Amazon EC2 Auto Scaling Group. This is achieved by way of an autoscaling lifecycle hook that interrupts the scale-out process so that a new revision application can be deployed before the new instance is included within an Amazon EC2 Auto Scaling Group.

It elaborates on the notes given within the following documentation:

[Tutorial: Use AWS CodeDeploy to deploy an application to an Amazon EC2 Auto Scaling group](https://docs.aws.amazon.com/codedeploy/latest/userguide/tutorials-auto-scaling-group.html)


#### Integrating AWS CodeDeploy with Amazon S3

A revision is a version of the source files that AWS CodeDeploy will deploy to your target instances or scripts that AWS CodeDeploy will run on these instances. Once you have added an [AppSpec](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-specification-files.html) file to your revision, you can then upload this code bundle as an archive to an Amazon S3 Bucket using the [push](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/push.html) API command as follows:

```

  aws deploy push
              --application-name <app-name>
              --s3-location s3://<bucket>/<key>
              [--ignore-hidden-files | --no-ignore-hidden-files]
              [--source <path>]
              [--description <description>]

```

The Amazon S3 Bucket needs to be in the same region as the instances you wish to deploy to and if successful then the [push](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/push.html) API command will return a message from which you can construct a valid [create-deployment](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/create-deployment.html) command call that will deploy to target instances the application revision that you just uploaded.

Have a look at the following script. Where I have gone through the process of doing just that to an already provisioned Amazon EC2 Auto Scaling Group.


```bash

automation/
│
└── push-s3-deploy-app-revision.sh

```

##### For Reference


- AWS CodeDeploy - [Push a revision for CodeDeploy to Amazon S3 (EC2/On-Premises deployments only)](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-revisions-push.html)

- AWS DevOps Blog - [Automatically Deploy from Amazon S3 using AWS CodeDeploy](https://aws.amazon.com/blogs/devops/automatically-deploy-from-amazon-s3-using-aws-codedeploy/)

> [push](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/push.html)

> [create-deployment](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/create-deployment.html)


#### AWS CodeDeploy Agent

For EC2/On-Premises deployments the AWS CodeDeploy service requires that an agent be installed on target instances. The AWS CodeDeploy Agent communicates outbound using HTTPS over port 443. Log files can be found here: 

`/var/log/aws/codedeploy-agent`

For convenience, this project manually installs the AWS CodeDeploy Agent via the Userdata Script facility of the Launch Template CloudFormation nested stack:

```bash

automation/
│
├── cfn-templates
│   │
│   └── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-ec2-asg.yaml

```
It's a bit of a mess but for reference here is a copy of the bash script:

```bash

#!/bin/bash -xe
# --- Clean AMI (previous agent caching info)
if [ -n "$( ls -A /opt/codedeploy-agent/bin/codedeploy-agent )" ]; then "/opt/codedeploy-agent/bin/codedeploy-agent" stop; yum erase codedeploy-agent -y; fi
# --- Update Packages (inc. aws-cfn-bootstrap)
# yum install -y aws-cfn-bootstrap
yum update -y
# --- Install yum packages
yum install -y ruby wget httpd
# --- Config alb health checks
echo "<h1>Hello from ${AWS::StackId}<h1>" >> /var/www/html/health.html
chmod 0644 /var/www/html/health.html
systemctl start httpd
systemctl enable httpd
# --- Install CodeDeploy Agent
cd /tmp
wget https://aws-codedeploy-${AWS::Region}.s3.${AWS::Region}.amazonaws.com/latest/install
chmod +x ./install
./install auto
# ---
# Retrive IMDSv2 token - valid 15mins
# export TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 900")
# All done so signal success
/opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackId} --resource PublicEC2AutoScaleGroup --region ${AWS::Region}

```

##### As an aside note: Installing the AWS CodeDeploy Agent via AWS Systems Manager

The AWS CodeDeploy Agent can be installed using AWS Systems Manager. It is the recommended method for installing as well as updating the agent.

There is a very useful service integration between AWS CodeDeploy and AWS Systems Manager. It can set up the installation as well as schedule updates to the AWS CodeDeploy Agent. You can find this when you manually create an AWS CodeDeploy Deployment Group via the AWS Console. Don't forget to include the Managed Policy: AmazonSSMManagedInstanceCore within your service role.

You can also install the AWS CodeDeploy Agent by calling the [create-association](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ssm/create-association.html) API command from AWS Systems Manager with the tags that were added when the Amazon EC2 Auto Scaling group was created.

For example:

```bash

aws ssm create-association
        --name AWS-ConfigureAWSPackage
        --targets Key=tag:Name,Values=CodeDeployDemo
        --parameters action=Install, name=AWSCodeDeployAgent
        --schedule-expression "cron(0 2 ? * SUN *)" 

```

Note:

The AWS CodeDeploy Agent is not required for deployments that use the Amazon ECS or AWS Lambda compute platform.

For further information:

- AWS CodeDeploy - [Working with the AWS CodeDeploy Agent](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent.html)


#### Infrastructure As Code

This stand-alone solution documents a complete infrastructure definition and takes the form of nested AWS CloudFormation templates. These are provisioned via the bash script:

```bash

automation/
│
└── provision-infrastructure-cfn-templates.sh

```


This script orchestrates the creation of all the Cloud resource components required to demonstrate how the Amazon EC2 Auto Scaling service integrates with AWS CodeDeploy. The CloudFormation template hierarchical structure is as follows:


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

AWS CodeDeploy supports Amazon EC2 Auto Scaling. When new Amazon EC2 instances are launched as part of an Amazon EC2 Auto Scaling Group, AWS CodeDeploy can deploy application revisions to the new instances automatically as part of the provisioning process. All that you need to take care of are the special authorizations required by the EC2 IAM Instance profile as well as those of the AWS CodeDeploy Service Role. Have a look here for what is required:

```bash

automation/
│
└── cfn-templates
    │
    └── demo-cert-devops-codedeploy-ec2-s3-asg-cfn-iam.yaml.......(IAM ROLES)

```

Another way of looking at it is instead of designating a Deployment Group with Tags just designate with an Amazon EC2 Auto Scaling Group name and service role - simple.

#### Lifecycle Hook

In order for AWS CodeDeploy to deploy an application revision to new EC2 instances during an Auto Scaling scale-out event, AWS CodeDeploy uses an Auto Scaling lifecycle hook. It installs this using its specially authorized service role.

When you create or update a deployment group to include an Auto Scaling group, AWS CodeDeploy accesses the Auto Scaling group using the AWS CodeDeploy service role, and then installs a lifecycle hook in the Auto Scaling group.

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
During AWS CodeDeploy deployments, a load balancer prevents internet traffic from being routed to instances when they are not ready, are currently being deployed to, or are no longer needed as part of an environment.



---



#### Reference:


- AWS CodeDeploy - [Integrating AWS CodeDeploy with Amazon EC2 Auto Scaling](https://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-aws-auto-scaling.html).

- Amazon EC2 Auto Scaling - [Amazon EC2 Auto Scaling lifecycle hooks](https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html)

- AWS Command Line Interface - [deploy](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/deploy/index.html#cli-aws-deploy)

- AWS CloudFormation - [AWS CodeDeploy resource type reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_CodeDeploy.html)

- AWS CodeDeploy - [Push a revision for AWS CodeDeploy to Amazon S3](https://docs.aws.amazon.com/codedeploy/latest/userguide/application-revisions-push.html)

- AWS CodeDeploy - [Integrating AWS CodeDeploy with Elastic Load Balancing](https://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-aws-elastic-load-balancing.html)

- AWS CodeDeploy - [Set up a load balancer in Elastic Load Balancing for AWS CodeDeploy Amazon EC2 deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-groups-create-load-balancer.html)

Under the Hood: AWS CodeDeploy and Auto Scaling Integration 
https://aws.amazon.com/blogs/devops/under-the-hood-aws-codedeploy-and-auto-scaling-integration/

- AWS CodeDeploy - [How Amazon EC2 Auto Scaling works with AWS CodeDeploy: Order of events in AWS CloudFormation cfn-init scripts](https://docs.aws.amazon.com/codedeploy/latest/userguide/integrations-aws-auto-scaling.html#integrations-aws-auto-scaling-behaviors-event-order)


- AWS CodeDeploy - [Working with the AWS CodeDeploy Agent](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent.html)




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





AWS CloudFormation helper scripts reference
https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-helper-scripts-reference.html




# !! Note: for blue/green deployments, AWS CloudFormation supports Lambda
# deployments ONLY - NOT EC2!! EC2 blue/green deployments conducted
# manually via Console only.
# For ECS blue/green deployments use AWS::CodeDeploy::BlueGreen hook


Note on ec2 blue/green deployment: did not use a lauchtemplate here since replacement instances 
would not have the AWS CodeDeploy Agent installed on them as the lauchtemplate would only be used 
during infrastructure provisioning and not during blue/green deployment.