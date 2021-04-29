#!/usr/bin/env bash

# By using user/bin/env bash, the shell script can be called portable as the path of bash is not relevant
# File: set-aws-profile-credentials.sh
# Date: 29 April 2021
# Author: Lars Kinder

# This script sets the environment variables needed to run AWS without the --profile extension.
# Usage: Please append the profile you want to use during the session as a parameter to this script like
# . ./set-aws-profile-credentials.sh test-profile
# Precondition: Profile was added using aws configure --profile <NAME> to credential and config files.

#source . ./set-aws-profile-credentials.sh

set -e

# Define output colors
# Green being okay, red something went wrong, no color to remove formating.
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Set working variables
AWS_FILE_PATH=$HOME/.aws
AWS_CREDENTIAL_FILE=""
AWS_CONFIG_FILE=""
CRED_PREFIX="cred"
CONFIG_PREFIX="config"
AWS_ACCESS_KEY_STRING="aws_access_key"
AWS_SECRET_ACCESS_KEY_STRING="aws_secret_access_key"

# Set AWS Access credentials
AWS_PROFILE=""
AWS_ACCESS_KEY=""
AWS_SECRET_ACCESS_KEY=""
AWS_ROLE_ARN=""

if [[ -z "$(find $AWS_FILE_PATH -maxdepth 1 -name "${CONFIG_PREFIX}*")" ]]
  then
    echo -e "${RED}No config file found in ${AWS_FILE_PATH} directory.${NC}"
    exit 0
  else
    echo -e "${GREEN}Config file found.${NC}"
    # Use for debugging
    # echo -e "${GREEN}At least one files found $(ls -A $AWS_FILE_PATH)${NC}"
    AWS_CREDENTIAL_FILE=$(find $AWS_FILE_PATH -maxdepth 1 -name "${CRED_PREFIX}*")
    AWS_CONFIG_FILE=$(find $AWS_FILE_PATH -maxdepth 1 -name "${CONFIG_PREFIX}*")
    # Only for debugging
    echo $AWS_CREDENTIAL_FILE
    echo $AWS_CONFIG_FILE
    AWS_PROFILE=$1
    PROFILE_PATTERN_CRED_FILE='\['${AWS_PROFILE}'\]'
    PROFILE_PATTERN_CONF_FILE='\['"profile "${AWS_PROFILE}'\]'
    # echo "I am here" $PROFILE_PATTERN_CONF_FILE
    # echo $PROFILE_PATTERN_CRED_FILE
    # echo $PROFILE_PATTERN_CONF_FILE

    if [[ -z $(grep "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE) ]]
    then
      echo -e "${RED}Sorry, but I wasn't able to find your profile \"$AWS_PROFILE\" in $AWS_CONFIG_FILE!${NC}"
      echo $(grep "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE)
#      exit 1
    else
      echo -e "${GREEN}Found your profile \"$AWS_PROFILE\" in $AWS_CONFIG_FILE!${NC}"
      
      if [[ -z $(grep -A2 "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE | cut -d "=" -f 2) ]]
        then
          echo -e "${RED}Something went wrong!${NC}"
        else
#          if [[ $(grep -A4 "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE | xargs | awk {'print $3'}) ] != "role_arn" && [ $(grep -A4 <=EOF
#          $PROFILE_PATTERN_CONF_FILE $AWS_CONFIG_FILE | xargs | awk {'print $5'})  ]]
#          EOF
          if [ "$(grep -A4 "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE | xargs | awk {'print $3'})" != "role_arn" ] &&
                 [ "$(grep -A4 "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE | xargs | awk {'print $5'})" != "arn*" ]

            then
              echo -e "${RED}Maleformating, didn't find an arn to use.${NC}"
              echo << EOF  "${RED}The script currently expects a certain formating in the config as well as the credentials file.
Expected:
1. [profile xyz]
2. role_arn
3. source_profile
4. ..."
EOF
            else
              AWS_ROLE_ARN="$(grep -A4 "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE | xargs | awk {'print $5'})"
              echo -e "${GREEN}AWS ROLE ARN: $AWS_ROLE_ARN${NC}"
              SOURCE_PROFILE="$(grep -A4 "${PROFILE_PATTERN_CONF_FILE}" $AWS_CONFIG_FILE | xargs | awk {'print $8'})"
              echo -e "${GREEN}AWS SOURCE PROFILE: $SOURCE_PROFILE${NC}"

              if [[ -z $(grep -A2 $SOURCE_PROFILE $AWS_CREDENTIAL_FILE | cut -d "=" -f 2) ]]
                then
                  echo -e "${RED}Something went wrong!${NC}"
                  echo "$(grep -A2 $SOURCE_PROFILE $AWS_CREDENTIAL_FILE | cut -d "=" -f 2)"
                else
                  if [[ -z $(grep -A2 $SOURCE_PROFILE $AWS_CREDENTIAL_FILE | xargs | awk {'print $4'}) ]]
                    then
                      echo "${RED}ACCESS KEY field seems to be empty!${NC}"
                    else
                      AWS_ACCESS_KEY="$(grep -A2 $SOURCE_PROFILE $AWS_CREDENTIAL_FILE | xargs | awk {'print $4'})"
                      echo "${GREEN}ACCESS KEY was set using linked source profile.${NC}"
                      AWS_SECRET_ACCESS_KEY="$(grep -A2 $SOURCE_PROFILE $AWS_CREDENTIAL_FILE | xargs | awk {'print $7'})"
                      echo "${GREEN}SECRET ACCESS KEY was set using linked source profile.${NC}"

                      export AWS_PROFILE=$AWS_PROFILE
                      export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
                      export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

                      # Assume role for logging in to the project accounts
                      ROLE_SESSION_NAME=$AWS_PROFILE
                      echo "${GREEN}Starting aws assume process.${NC}"
                      if aws sts assume-role --role-arn $AWS_ROLE_ARN --role-session-name $ROLE_SESSION_NAME --profile $AWS_PROFILE >/dev/null
                          then
                              echo "${GREEN}Assume role successful${NC}"
                              echo "${GREEN}You are now logged in to the account: $(aws sts get-caller-identity)${NC}"
                          else
                              echo "${RED}Something went wrong${NC}"
                      fi
                  fi
              fi
          fi
      fi
  fi
fi

set +e

