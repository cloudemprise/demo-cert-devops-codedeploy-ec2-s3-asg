#!/bin/bash -e
# debug options include -v -x
# ddeploy-application-revision.sh
# deploy an application revision to target EC2 instances 
# from an S3 bucket.

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


#-----------------------------
# Request Bucket Name 
PROJECT_BUCKET="demo-cert-devops"
while true
do
  # -e : stdin from terminal
  # -r : backslash not an escape character
  # -p : prompt on stderr
  # -i : use default buffer val
  read -er -i "$PROJECT_BUCKET" -p "Enter the Name of the Project Bucket ..........: " USER_INPUT
  REGEX='(^[a-z0-9]([a-z0-9-]*(\.[a-z0-9])?)*$)'
  if [[ "${USER_INPUT:=$PROJECT_BUCKET}" =~ $REGEX ]]
  then
    echo "Project Bucket Name is valid ..................: $USER_INPUT"
    PROJECT_BUCKET=$USER_INPUT
    break
  else
    echo "Error! Bucket Name must be S3 Compatible ......: $USER_INPUT"
  fi
done
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#-----------------------------
# Request Bucket Prefix
PROJECT_PREFIX="codedeploy"
while true
do
  # -e : stdin from terminal
  # -r : backslash not an escape character
  # -p : prompt on stderr
  # -i : use default buffer val
  read -er -i "$PROJECT_PREFIX" -p "Enter the Name of the Project Bucket Prefix ...: " USER_INPUT
  REGEX='(^[a-z0-9]([a-z0-9/-]*(\.[a-z0-9])?)*$)'
  if [[ "${USER_INPUT:=$PROJECT_PREFIX}" =~ $REGEX ]]
  then
    echo "Bucket Prefix is valid ........................: $USER_INPUT"
    PROJECT_PREFIX=$USER_INPUT
    break
  else
    echo "Error! Bucket Prefix must be S3 Compatible ....: $USER_INPUT"
  fi
done
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# END   USER INPUT
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# START   UPLOAD & DEPLOY NEW REVISION
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


#-----------------------------
# Bundles and uploads application revision to S3
APPLICATION_NAME="$PROJECT_NAME-app"
APPLICATION_DESCRIPTION="'New Revision Application Deployment'"
# ---
PROJECT_LOCALE="${PROJECT_BUCKET}/${PROJECT_PREFIX}/${PROJECT_NAME}"
S3_OBJECT="s3://$PROJECT_LOCALE/app/sample-application.zip"
# ---
DEPLOY_COMMAND=$(aws deploy push \
                      --application-name "$APPLICATION_NAME" \
                      --s3-location "$S3_OBJECT" \
                      --source "../app/" \
                      --profile "$AWS_PROFILE" \
                      --region "$AWS_REGION" \
                      --ignore-hidden-files \
                      --description "$APPLICATION_DESCRIPTION" \
                  )
#----------------------------------------------
# Process returned command message
if [[ $? -eq 0 ]]; then
  DEPLOY_GRP_NAME="$PROJECT_NAME-deploy-group"
  DEPLOY_CFG_NAME="CodeDeployDefault.AllAtOnce"
  DEPLOY_DESCRIPTION="'New Revision Deployment'"
  # stripe out unwanted prefix
  DEPLOY_COMMAND="${DEPLOY_COMMAND#'To deploy with this revision, run:'}"
  # parameter expansion to replace command options provided above
  DEPLOY_COMMAND="${DEPLOY_COMMAND/<deployment-group-name>/"$DEPLOY_GRP_NAME"}"
  DEPLOY_COMMAND="${DEPLOY_COMMAND/<deployment-config-name>/"$DEPLOY_CFG_NAME"}"
  DEPLOY_COMMAND="${DEPLOY_COMMAND/<description>/"$DEPLOY_DESCRIPTION"}"
  #echo "Returned Command Message ......................: $DEPLOY_COMMAND"
  echo "Application revision push Success .............: $S3_OBJECT"
  # ---
  # rebuild command with some options included
  DEPLOY_COMMAND="${DEPLOY_COMMAND} --profile ${AWS_PROFILE} --region ${AWS_REGION} --output text"
  # execute command stored in variable : aws deploy create-deployment
  DEPLOYMENT_ID=$(eval "$DEPLOY_COMMAND")
  if [[ $? -eq 0 ]]; then
    echo "Deployment Creation Successful with ID ........: $DEPLOYMENT_ID"
  else
    echo "Deployment Creation Failed ....................: $DEPLOYMENT_ID"
    exit 1
  fi
  # ---
else
  echo "Application revision push Failed ..............: $S3_OBJECT"
  exit 1
fi
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# END   UPLOAD & DEPLOY NEW REVISION
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#-----------------------------
# Calculate Script Total Execution Time
TIME_END_PT=$(date +%s)
TIME_DIFF_PT=$((TIME_END_PT - TIME_START_PROJ))
echo "Total Finished Execution Time .................: \
$(( TIME_DIFF_PT / 3600 ))h $(( (TIME_DIFF_PT / 60) % 60 ))m $(( TIME_DIFF_PT % 60 ))s"
#.............................
