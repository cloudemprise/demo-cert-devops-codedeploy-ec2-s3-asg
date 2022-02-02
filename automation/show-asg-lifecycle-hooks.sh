#!/bin/bash -e
# debug options include -v -x
# show-asg-lifecycle-hooks.sh
# comment here

# Debug pause
#read -p "Press enter to continue"


#!! COMMENT Construct Begins Here:
: <<'END'
#!! COMMENT BEGIN

#!! COMMENT END
END
#!! COMMENT Construct Ends Here:


#-----------------------------
# Record Script Start Execution Time
TIME_START_PROJ=$(date +%s)
TIME_STAMP_PROJ=$(date "+%Y-%m-%d %Hh%Mm%Ss")
echo "The Time Stamp ................................: $TIME_STAMP_PROJ"
#.............................


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# START   USER INPUT 
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#-----------------------------
# Request Named Profile
AWS_PROFILE="default"
while true
do
  # -e : stdin from terminal
  # -r : backslash not an escape character
  # -p : prompt on stderr
  # -i : use default buffer val
  read -er -i "$AWS_PROFILE" -p "Enter Project AWS CLI Named Profile ...........: " USER_INPUT
  if aws configure list-profiles 2>/dev/null | grep -qw -- "$USER_INPUT"
  then
    echo "Project AWS CLI Named Profile is valid ........: $USER_INPUT"
    AWS_PROFILE=$USER_INPUT
    break
  else
    echo "Error! Project AWS CLI Named Profile invalid ..: $USER_INPUT"
  fi
done
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#-----------------------------
# Request Region
AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE")
while true
do
  # -e : stdin from terminal
  # -r : backslash not an escape character
  # -p : prompt on stderr
  # -i : use default buffer val
  read -er -i "$AWS_REGION" -p "Enter Project AWS CLI Region ..................: " USER_INPUT
  if aws ec2 describe-regions --profile "$AWS_PROFILE" --query 'Regions[].RegionName' \
    --output text 2>/dev/null | grep -qw -- "$USER_INPUT"
  then
    echo "Project AWS CLI Region is valid ...............: $USER_INPUT"
    AWS_REGION=$USER_INPUT
    break
  else
    echo "Error! Project AWS CLI Region is invalid ......: $USER_INPUT"
  fi
done
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#-----------------------------
# Request Project Name
PROJECT_NAME="demo-cert-devops-codedeploy-ec2-s3-asg"
while true
do
  # -e : stdin from terminal
  # -r : backslash not an escape character
  # -p : prompt on stderr
  # -i : use default buffer val
  read -er -i "$PROJECT_NAME" -p "Enter the Name of this Project ................: " USER_INPUT
  REGEX='(^[a-z0-9]([a-z0-9-]*(\.[a-z0-9])?)*$)'
  if [[ "${USER_INPUT:=$PROJECT_NAME}" =~ $REGEX ]]
  then
    echo "Project Name is valid .........................: $USER_INPUT"
    PROJECT_NAME=$USER_INPUT
    break
  else
    echo "Error! Project Name must be S3 Compatible .....: $USER_INPUT"
  fi
done
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# END   USER INPUT
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# START   INVESTIGATE AUTOSCALING GROUP
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Query string for multiple Tags
# --query "AutoScalingGroups[?Tags[?(Key=='Function')&&(Value=='cert-devops')]] | [?Tags[?(Key=='Project')&&(Value=='demo')]]".AutoScalingGroupName \
# Query string for single Tag
# --query "AutoScalingGroups[?Tags[?(Key=='Function')&&(Value=='cert-devops')]]".AutoScalingGroupName \
#

#----------------------------------------------
# Grab the Auto Scaling Group Name from the Tags
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --output text \
      --query "AutoScalingGroups[?Tags[?(Key=='Function')&&(Value=='cert-devops')]]".AutoScalingGroupName \
  )

# ---
# Display info about lifecycle hooks of the Auto Scaling Group.
echo "Current AutoScaling Lifecycle Hooks ...........: "
printf '\n'
aws autoscaling describe-lifecycle-hooks \
      --auto-scaling-group-name "$ASG_NAME" \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --output table
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

# Grab the current Desired Capacity
ASG_CAPACITY_DESIRED=\
$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --query 'AutoScalingGroups[].DesiredCapacity' \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \
      --output text
  )
printf '\n'
echo "Current AutoScaling Group DesiredCapacity .....: $ASG_CAPACITY_DESIRED"

# Increment current Desired Capacity 
ASG_CAPACITY_DESIRED="$((ASG_CAPACITY_DESIRED + 1))"
read -p "Press Enter to Increment DesiredCapacity to ...: $ASG_CAPACITY_DESIRED"
#echo "DesiredCapacity = $((ASG_CAPACITY_DESIRED + 1))"
#echo "DesiredCapacity = $ASG_CAPACITY_DESIRED"


# Update config Auto Scaling group desired capacity
aws autoscaling update-auto-scaling-group \
      --auto-scaling-group-name "$ASG_NAME" \
      --desired-capacity "$ASG_CAPACITY_DESIRED" \
      --max-size "$((ASG_CAPACITY_DESIRED + 1))" \
      --profile "$AWS_PROFILE" \
      --region "$AWS_REGION" \


# Monitor Scale-Out Instance Status
MONITOR_COMMAND="aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names $ASG_NAME \
      --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
      --profile $AWS_PROFILE \
      --region $AWS_REGION \
      --output table"
#echo $MONITOR_COMMAND
eval "watch -n 1 $MONITOR_COMMAND"



#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# END   INVESTIGATE AUTOSCALING GROUP
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<



#-----------------------------
# Calculate Script Total Execution Time
TIME_END_PT=$(date +%s)
TIME_DIFF_PT=$((TIME_END_PT - TIME_START_PROJ))
echo "Total Finished Execution Time .................: \
$(( TIME_DIFF_PT / 3600 ))h $(( (TIME_DIFF_PT / 60) % 60 ))m $(( TIME_DIFF_PT % 60 ))s"
#.............................
