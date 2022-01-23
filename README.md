# demo-cert-devops-codedeploy-ec2-enhanced
To Be Determined


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