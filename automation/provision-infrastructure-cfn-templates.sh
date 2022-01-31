#!/bin/bash -e
# debug options include -v -x
# provision-infrastructure-cfn-templates.sh 
# A script to provision infrastructure for a CodeDeploy sample 
# demonstration project.

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

#-----------------------------
# Request EC2 SSH Key Name
EC2_SSH_KEY_NAME="aws.dev.ec2.ssh.key.${AWS_REGION}"
while true
do
  # -e : stdin from terminal
  # -r : backslash not an escape character
  # -p : prompt on stderr
  # -i : use default buffer val
  read -er -i "$EC2_SSH_KEY_NAME" -p "Enter Project EC2 SSH Key Name ................: " USER_INPUT
  if aws ec2 describe-key-pairs --profile "$AWS_PROFILE" --query 'KeyPairs[].KeyName' \
    --region "$AWS_REGION" --output text 2>/dev/null | grep -qw -- "$USER_INPUT"
  then
    echo "Project EC2 SSH Key Name is found .............: $USER_INPUT"
    EC2_SSH_KEY_NAME=$USER_INPUT
    break
  else
    echo "Error! Project EC2 SSH Key Name is NOT found ..: $USER_INPUT"
  fi
done
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#-----------------------------
# Variable Creation
#-----------------------------
# Name given to Cloudformation Stack
STACK_NAME="$PROJECT_NAME-stack"
echo "The Stack Name ................................: $STACK_NAME"
# Get Account(ROOT) ID
AWS_ACC_ID=$(aws sts get-caller-identity --query 'Account' --output text --profile "$AWS_PROFILE" \
  --region "$AWS_REGION")
echo "The Root Account ID ...........................: $AWS_ACC_ID"
# Console Admin profile userid
AWS_USER_ADMIN="usr.console.admin"
AWS_USERID_ADMIN=$(aws iam get-user --user-name "$AWS_USER_ADMIN" --query 'User.UserId' \
  --output text --profile "$AWS_PROFILE" --region "$AWS_REGION")
echo "The Console Admin userid ......................: $AWS_USERID_ADMIN"
# CLI profile userid
AWS_USERID_CLI=$(aws sts get-caller-identity --query 'UserId' --output text \
  --profile "$AWS_PROFILE" --region "$AWS_REGION")
echo "The Script Caller userid ......................: $AWS_USERID_CLI"
#-----------------------------
# Script caller IP CIDR for SSH Bastion Host (if needed)
SSH_ACCESS_CIDR="$(curl -s https://checkip.amazonaws.com/)/32"
echo "The Script Caller IP CIDR  ....................: $SSH_ACCESS_CIDR"
# Grab the latest AMI
# To get a complete list of all available Public Parameter Amazon Linux AMIs:
# aws ssm get-parameters-by-path --path "/aws/service/ami-amazon-linux-latest"
AMI_NAME="/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
AMI_LATEST=$(aws ssm get-parameters --output text --names "$AMI_NAME" --profile "$AWS_PROFILE" \
  --query 'Parameters[0].[Value]' --region "$AWS_REGION")
echo "The latest AMI ................................: $AMI_LATEST"
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# END   USER INPUT
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# START   UPLOAD ARTIFACTS
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


#-----------------------------
# Compress and Upload Sample Application to S3
PROJECT_LOCALE="${PROJECT_BUCKET}/${PROJECT_PREFIX}/${PROJECT_NAME}"
S3_OBJECT="s3://$PROJECT_LOCALE/app/sample-application.tar.gz"
if [[ $(tar -zchf - -C ../app/ . | aws s3 cp - ${S3_OBJECT} --profile "$AWS_PROFILE" --region "$AWS_REGION") -ne 0 ]]
# tar -z : Filter the archive through gzip
# tar -c : Create a new archive
# tar -f : Use  archive file
# tar -h : Follow symlinks  
then
  echo "Sample Application Failed to Uploaded to S3 ...: ${S3_OBJECT}"
  exit 1
else
  echo "Sample Application Uploaded to S3 Location ....: ${S3_OBJECT}"
fi
#.............................


#----------------------------------------------
# Upload Cloudformation Template artifacts to S3
PROJECT_LOCALE="${PROJECT_BUCKET}/${PROJECT_PREFIX}/${PROJECT_NAME}"
find -L ./cfn-templates -type f -name "*.yaml" ! -path "*/scratch/*" -print0 |
# -L : Follow symbolic links
  while IFS= read -r -d '' FILE
  do
    if [[ ! -s "$FILE" ]]; then
      echo "Invalid Cloudformation Template Document ......: $FILE"
      exit 1
      # ...
    elif (aws s3 cp "$FILE" "s3://$PROJECT_LOCALE${FILE#.}" --profile "$AWS_PROFILE" \
          --region "$AWS_REGION" > /dev/null)
    then
      echo "Uploading Cloudformation Template to S3 .......: s3://$PROJECT_LOCALE${FILE#.}"
      # ...
    else continue
    fi
  done
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# END   UPLOAD ARTIFACTS 
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# START   CLOUDFORMATION STACK CREATION
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# ___
TEMPLATE_URL="https://${PROJECT_BUCKET}.s3.${AWS_REGION}.amazonaws.com/\
${PROJECT_PREFIX}/${PROJECT_NAME}/cfn-templates/${PROJECT_NAME}-cfn.yaml"
# ___
echo "Cloudformation Stack Creation Initiated .......: "
echo "Cloudformation Stack Template URL .............: $TEMPLATE_URL"
# ___
STACK_ID=$(aws cloudformation create-stack \
              --stack-name "$STACK_NAME" \
              --template-url "$TEMPLATE_URL" \
              --on-failure "DO_NOTHING" \
              --capabilities "CAPABILITY_NAMED_IAM" "CAPABILITY_AUTO_EXPAND" \
              --tags Key=Name,Value="$PROJECT_NAME" \
              --region "$AWS_REGION" \
              --profile "$AWS_PROFILE" \
              --output text \
              --parameters \
                ParameterKey=ProjectName,ParameterValue="$PROJECT_NAME" \
                ParameterKey=ProjectBucket,ParameterValue="$PROJECT_BUCKET" \
                ParameterKey=ProjectPrefix,ParameterValue="$PROJECT_PREFIX" \
                ParameterKey=SshAccessKeyName,ParameterValue="$EC2_SSH_KEY_NAME" \
                ParameterKey=SshAccessCIDR,ParameterValue="$SSH_ACCESS_CIDR"\
                ParameterKey=LatestAmi,ParameterValue="$AMI_LATEST" \
          )
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#----------------------------------------------
# Wait for stack creation to complete
if [[ $? -eq 0 ]]; then
  echo "Cloudformation Stack Creation In Progress .....: $STACK_ID"
  CHECK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_ID" --output text \
    --query 'Stacks[0].StackStatus' --profile "$AWS_PROFILE" --region "$AWS_REGION")
  while [[ $CHECK_STATUS == "REVIEW_IN_PROGRESS" ]] || [[ $CHECK_STATUS == "CREATE_IN_PROGRESS" ]]
  do
      # Wait x seconds and then check stack status again
      sleep 5
      printf '.'
      CHECK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_ID" --output text \
        --query 'Stacks[0].StackStatus' --profile "$AWS_PROFILE" --region "$AWS_REGION")
  done
  printf '\n'
fi
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#----------------------------------------------
# Validate stack creation Success
if (aws cloudformation wait stack-create-complete --stack-name "$STACK_ID" \
    --profile "$AWS_PROFILE" --region "$AWS_REGION")
then 
  echo "Cloudformation Stack Create Process Complete ..: $BUILD_COUNTER"
else 
  echo "Error: Stack Creation Failed. Exiting Now .....: "
  exit 1
fi
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#----------------------------------------------
# Calculate Stack Creation Execution Time
TIME_END_PT=$(date +%s)
TIME_DIFF_PT=$((TIME_END_PT - TIME_START_PROJ))
echo "$BUILD_COUNTER Finished Execution Time ................: \
$(( TIME_DIFF_PT / 3600 ))h $(( (TIME_DIFF_PT / 60) % 60 ))m $(( TIME_DIFF_PT % 60 ))s"

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
# END   CLOUDFORMATION STACK CREATION STAGE1
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#-----------------------------
# Calculate Script Total Execution Time
TIME_END_PT=$(date +%s)
TIME_DIFF_PT=$((TIME_END_PT - TIME_START_PROJ))
echo "Total Finished Execution Time .................: \
$(( TIME_DIFF_PT / 3600 ))h $(( (TIME_DIFF_PT / 60) % 60 ))m $(( TIME_DIFF_PT % 60 ))s"
#.............................
