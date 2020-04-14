#!/bin/bash

RED="\033[0;31m" # Used to indicate Failure
GREEN="\033[0;32m" # Used to indicate success
YELLOW="\033[0\1;33m" # Used to indicate a section is starting
LBLUE="\033[0;36m" # Used to indicate a piece of data produced
BLUE="\033[0;34m" # Used to describe what the system is doing
PURPLE="\033[0;35m" # Used to indicate a Prompt
NC="\033[0m"

PrintRed () { 
  printf "${RED}$1${NC}" 
}
PrintRedLn () { 
  PrintRed "$1\n" 
}
PrintYellow () { 
  printf "${YELLOW}$1${NC}" 
}
PrintYellowLn () { 
  PrintYellow "$1\n" 
}
PrintGreen () { 
  printf "${GREEN}$1${NC}" 
}
PrintGreenLn () { 
  PrintGreen "$1\n" 
}
PrintLBlue () {
  printf "${LBLUE}$1${NC}" 
}
PrintLBlueLn () { 
  PrintLBlue "$1\n" 
}
PrintBlue () {
  printf "${BLUE}$1${NC}" 
}
PrintBlueLn () { 
  PrintBlue "$1\n" 
}
PrintPurple () { 
  printf "${PURPLE}$1${NC}" 
}
PrintPurpleLn () { 
  PrintPurple "$1\n" 
}

set -e # Causes the program to crash if any subcommands fail.

PrintYellowLn "\n### Validating Environment State"
PrintBlueLn "Checking Permissions and Tools..."
PrintBlue "  Not Running as Sudo... "
if [ "$EUID" -ne 0 ]
then
  PrintGreenLn "Pass"
else 
  PrintRedLn "Fail"
  PrintRedLn "Please don't run this script as root: \n  ./create_new_project.sh"
  exit 1
fi

ValidateCLIIsInstalled () {
  PrintBlue "  CLI $1 Installed... "
  if [ -n "$(command -v $1)" ]
  then
    PrintGreenLn "Pass"
  else
    PrintRedLn "Fail"
    PrintRedLn "To run this tool, please install the CLI $1"
    exit
  fi
}

ValidateCLIIsInstalled "aws"
ValidateCLIIsInstalled "git"
ValidateCLIIsInstalled "hub"
ValidateCLIIsInstalled "travis"
PrintGreenLn "All Dependencies Are Satisfied! Let's go!"


PrintYellowLn "\n### User Input"
InputOrDefault () {
  local __resultvar=$1
  read -r InputOrDefaultTmpVar
  if [ -z "$InputOrDefaultTmpVar" ]
  then 
    InputOrDefaultTmpVar=$2
  fi
  eval $__resultvar="'$InputOrDefaultTmpVar'"
}

PrintPurpleLn "Creating a new project. Please enter a name for the new project (lower case, no special characters or spaces)."
InputOrDefault ProjectName "defaultproject"

PrintPurple "Excellent. Creating Project "
PrintGreenLn "$ProjectName"
BaseDirDefault="/Users/gradyward/go/src"
PrintPurple "Next, please specify the directory that you want this project to be created in. This should be an absolute path from /. Omit the trailing slash. If not specified, your code will live in "
PrintBlueLn "$BaseDirDefault"
InputOrDefault BaseDir "$BaseDirDefault"

NewProjectFolder="$BaseDir/$ProjectName"
OriginalPWD="$PWD"
TemplateFolder="$OriginalPWD/template"

PrintBlue "Creating Folder $NewProjectFolder... "
mkdir -p "$NewProjectFolder"
PrintGreenLn "Done."

PrintPurple "Great! Next, please give us the name of the first lambda you want to write in this project. The name you enter here will be prefixed by the project name in most contexts, so give a project-specific name. This should not include spaces or other special characters and should be lowercase. If not specified, your first lambda will be called "
PrintBlueLn "helloworld"
InputOrDefault FirstLambdaName "helloworld"

FirstLambdaNameUcDefault="$(tr '[:lower:]' '[:upper:]' <<< ${FirstLambdaName:0:1})${FirstLambdaName:1}"
PrintPurple "Next, give us the UpperCasing of the lambda name. For example, if your lambda is helloworld, you might want it to appear as HelloWorld in capitalization sensitive domains. If nothing is specified, we will use "
PrintBlueLn "$FirstLambdaNameUcDefault" 
InputOrDefault FirstLambdaNameUc "$FirstLambdaNameUcDefault"

PrintPurple "Finally, what region would you like this lambda to run in? If not specified, they will run in "
PrintBlueLn "us-east-2"
InputOrDefault ProjectRegion "us-east-2"

PrintYellowLn "\n### Creating and Building Project and First Lambda"
CopyFilesOverWithSubstitution () {
  PrintBlue "Creating $NewProjectFolder/$2 ... "
  sed \
    -e "s/PROJECT_NAME/$ProjectName/g" \
    -e "s/PROJECT_REGION/$ProjectRegion/g" \
    -e "s/FIRST_LAMBDA_NAME/$FirstLambdaName/g" \
    -e "s/FIRST_LAMBDA_ARN/$FirstLambdaArnRegexSafe/g" \
    -e "s/FIRST_LAMBDA_FULL_NAME/$FirstLambdaFullName/g" \
    -e "s/LAMBDA_NAME/$FirstLambdaName/g" \
    -e "s/FIRST_LAMBDA_EXECUTOR_ROLE_ARN/$FirstLambdaExecutorRoleArnRegexSafe/g" \
    -e "s/FIRST_LAMBDA_NAME_UC/$FirstLambdaNameUc/g" \
    -e "s/LAMBDA_NAME_UC/$FirstLambdaNameUc/g" \
    -e "s/TRAVIS_USER_ACCESS_KEY_ID/$TravisUserAccessKeyId/g" \
    -e "s/TRAVIS_USER_ENCRYPTED_SECRET_ACCESS_KEY/$TravisUserEncryptedSecretAccessKeyRegexSafe/g" \
  "$TemplateFolder/$1" > "$NewProjectFolder/$2"
  PrintGreenLn "Done."
}

CopyFilesOverWithSubstitution "README.md" "README.md"
CopyFilesOverWithSubstitution "LAMBDA_NAME.go" "$FirstLambdaName.go"
CopyFilesOverWithSubstitution "LAMBDA_NAME_test.go" "${FirstLambdaName}_test.go"
CopyFilesOverWithSubstitution "LAMBDA_NAME.md" "$FirstLambdaName.md"

PrintBlue "Testing that the new lambda builds and passes tests... "
cd "$NewProjectFolder"
go test 1>/dev/null # Redirects STOUT only to dev null
PrintGreenLn "Done."

PrintBlue "Building and packaging the new lambda for initial deployment... "
env GOOS=linux GOARCH=amd64 go build -o "bin-$FirstLambdaName" "$FirstLambdaName.go" 1>/dev/null # Redirects STOUT only to dev null
zip -j "bin-$FirstLambdaName.zip" "bin-$FirstLambdaName" 1>/dev/null # Redirects STOUT only to dev null
PrintGreenLn "Done."

AllowAmazonToRunLambda="policies/allow-amazon-to-run-lambda-policy.json"
mkdir -p "$NewProjectFolder/policies"
CopyFilesOverWithSubstitution "$AllowAmazonToRunLambda" "$AllowAmazonToRunLambda"

PrintYellowLn "\n### Creating Lambda in AWS"
FirstLambdaFullName="$ProjectName-$FirstLambdaName"
FirstLambdaExecutorRole="$FirstLambdaFullName-executor"
PrintBlue "Creating AWS Executor Role for $FirstLambdaFullName: $FirstLambdaExecutorRole ... "
AwsCreateRoleCommand="aws iam create-role \
  --role-name $FirstLambdaExecutorRole \
  --assume-role-policy-document file://$NewProjectFolder/$AllowAmazonToRunLambda \
  --description AutoGeneratedRoleFor$FirstLambdaFullName"
AwsCreateRoleCommandResult="$($AwsCreateRoleCommand)"
PrintGreenLn "Done."

ExtractFieldFromJsonResult () {
  echo "$2" | tr '\n' ' ' | sed "s/^.*$1.: .\([^ \"]*\).*$/\1/"
}

FirstLambdaExecutorRoleId=$(ExtractFieldFromJsonResult "RoleId" "$AwsCreateRoleCommandResult")
FirstLambdaExecutorRoleArn=$(ExtractFieldFromJsonResult "Arn" "$AwsCreateRoleCommandResult")
PrintLBlueLn "  Executor Role Id = $FirstLambdaExecutorRoleId"
PrintLBlueLn "  Executor Role ARN = $FirstLambdaExecutorRoleArn"
FirstLambdaExecutorRoleArnRegexSafe=$(echo "$FirstLambdaExecutorRoleArn" | sed -e 's/[\/&]/\\&/g')

PrintBlue "Waiting 10s for role to be available for use in the lambda... "
sleep 10s
PrintGreenLn "Done."

PrintBlue "Creating Lambda on AWS... "
AwsCreateLambdaCommand="aws lambda create-function \
--function-name $FirstLambdaFullName \
--zip-file fileb://$NewProjectFolder/bin-$FirstLambdaName.zip \
--handler bin-$FirstLambdaName \
--runtime go1.x \
--role $FirstLambdaExecutorRoleArn"
AwsCreateLambdaCommandResult="$($AwsCreateLambdaCommand)"
PrintGreenLn "Done."
FirstLambdaArn=$(ExtractFieldFromJsonResult "FunctionArn" "$AwsCreateLambdaCommandResult")
PrintLBlueLn "  Lambda ARN = $FirstLambdaArn"
# TODO(grady) make this a function not a repeated oneoff
FirstLambdaArnRegexSafe=$(echo "$FirstLambdaArn" | sed -e 's/[\/&]/\\&/g')

PrintBlue "Waiting 10s for lambda to be callable... "
sleep 10s
PrintGreenLn "Done."

PrintYellowLn "\n### Testing Lambda"
InvokeResultFile="aws_lambda_invoke_result.txt"
PrintBlue "Attempting to call Lambda on AWS... "
PayloadInput="Sent request at $(date)"
Payload="{\"Input\": \"$PayloadInput\"}"
AwsLambdaInvokeCommand="aws lambda invoke \
--function-name $FirstLambdaFullName \
--payload '$Payload' \
$InvokeResultFile"
AwsLambdaInvokeCommandResult="$(eval $AwsLambdaInvokeCommand)"
PrintGreenLn "Done."
InvocationStatusCode=$(ExtractFieldFromJsonResult "StatusCode" "$AwsLambdaInvokeCommandResult")
PrintLBlueLn "  Status = $InvocationStatusCode"
InvocationResult=$(cat "$InvokeResultFile")
rm "$InvokeResultFile"
InvocationExpectation="\"This is the lambda $FirstLambdaName! request.Input=$PayloadInput\""
if [ "$InvocationResult" == "$InvocationExpectation" ]
then
  PrintLBlueLn "  Lambda response was as expected."
  PrintLBlueLn "    Expected : $InvocationExpectation"
  PrintLBlueLn "    Actual   : $InvocationResult"
else
  PrintRedLn "  Lambda response was not as expected."
  PrintRedLn "    Expected : $InvocationExpectation"
  PrintRedLn "    Actual   : $InvocationResult"
  exit
fi

PrintYellowLn "\n### Git Configuration"
CopyFilesOverWithSubstitution ".gitignore" ".gitignore"
PrintBlue "Setting up Local Git Configuration... "
git init -q
git add ".gitignore"
git add "README.md"
git add "$FirstLambdaName.go"
git add "${FirstLambdaName}_test.go"
git add "$FirstLambdaName.md"
git add "$AllowAmazonToRunLambda"
git commit -q -m "Initial Commit."
PrintGreenLn "Done."
PrintBlue "Creating Gitub Project and adding origin... "
set +e # TODO(grady) Eval whether this is still needed now that we're not running as sudo.
RepoCreateCommandResult=$(hub create "$ProjectName") # Command returns > 0, but actually works...
set -e
PrintGreenLn "Done."
PrintBlue "Pushing... "
git push -q --set-upstream origin master &> /dev/null
PrintGreenLn "Done."
PrintBlue "Validating Pull... "
git pull -q
PrintGreenLn "Done."


PrintYellowLn "\n### Configuring Travis"

PrintBlue "Waiting 10s for GitHub project to be callable... "
sleep 10s
PrintGreenLn "Done."
PrintBlue "Enabling Travis for Repo... "
travis sync --org --no-interactive &> /dev/null
travis enable --org --no-interactive --repo="gbdubs/$ProjectName"  &> /dev/null
PrintGreenLn "Done."

TravisUser="$ProjectName-travis"
PrintBlue "Creating User for Travis... "
AwsCreateTravisUserCommand="aws iam create-user --user-name $TravisUser"
AwsCreateTravisUserCommandResult="$($AwsCreateTravisUserCommand)"
PrintGreenLn "Done."
TravisUserId=$(ExtractFieldFromJsonResult "UserId" "$AwsCreateTravisUserCommandResult")
TravisUserArn=$(ExtractFieldFromJsonResult "Arn" "$AwsCreateTravisUserCommandResult")
PrintLBlueLn "  Travis User Id = $TravisUserId"
PrintLBlueLn "  Travis User Arn = $TravisUserArn"

PrintBlue "Creating Access Key for Travis User... "
AwsCreateKeyForTravisUserCommand="aws iam create-access-key --user-name $TravisUser"
AwsCreateKeyForTravisUserCommandResult="$($AwsCreateKeyForTravisUserCommand)"
PrintGreenLn "Done."
TravisUserAccessKeyId=$(ExtractFieldFromJsonResult "AccessKeyId" "$AwsCreateKeyForTravisUserCommandResult")
TravisUserSecretAccessKey=$(ExtractFieldFromJsonResult "SecretAccessKey" "$AwsCreateKeyForTravisUserCommandResult")
PrintLBlueLn "  Travis User Access Id = $TravisUserAccessKeyId"
PrintLBlueLn "  Travis User Secret Key = $TravisUserSecretAccessKey"
CopyFilesOverWithSubstitution ".travis.yml" ".travis.yml"
PrintBlue "Encrypting Travis User's Secret Key... "
echo "y" | travis encrypt "$TravisUserSecretAccessKey" --org --override --add &> /dev/null deploy.secret_access_key --repo "gbdubs/$ProjectName" 
#TravisUserEncryptedSecretAccessKey=$(travis encrypt --org --no-interactive secret_access_key="$TravisUserSecretAccessKey") # TODO(grady) attempt to silence this.
#TravisUserEncryptedSecretAccessKeyRegexSafe=$(echo "$TravisUserEncryptedSecretAccessKey" | sed -e 's/[\/&]/\\&/g') 
PrintGreenLn "Done."

TravisInlinePolicy="policies/travis-inline-policy.json"
CopyFilesOverWithSubstitution "policies/allow-travis-to-update-first-lambda.json" "$TravisInlinePolicy"

PrintBlue "Assigning Travis User an Inline Policy... "
AwsAttachTravisInlinePolicyCommand="aws iam put-user-policy --user-name $TravisUser --policy-name TravisInlinePolicy --policy-document file://$NewProjectFolder/$TravisInlinePolicy"
AwsAttachTravisInlinePolicyCommandResult="$($AwsAttachTravisInlinePolicyCommand)"
PrintGreenLn "Done."

PrintBlue "Pushing Travis Configuration to Github... "
git add ".travis.yml"
git add "$TravisInlinePolicy"
git commit -q -m "Adds Travis Configuration."
git push -q
git pull -q
PrintGreenLn "Done."

PrintYellowLn "\n### Verifying Travis Configuration by Changing Code + Verifying Delivery"

PrintBlue "Updating Lambda Logic + Tests... "
#TODO(grady) clean up this string duplication.
ModifiedMessage="This is the second iteration of the lambda, delivered by travis"
sed -i '' 's/This is the lambda/This is the second iteration of the lambda, delivered by travis/g' "$FirstLambdaName.go"
sed -i '' 's/This is the lambda/This is the second iteration of the lambda, delivered by travis/g' "${FirstLambdaName}_test.go"
PrintGreenLn "Done."
PrintBlue "Pushing Changes to Github... "
git add "$FirstLambdaName.go"
git add "${FirstLambdaName}_test.go"
git commit -q -m "Update to Lambda Logic to attempt to verify continuous delivery"
git push -q
git pull -q
PrintGreenLn "Done."
PrintBlue "Waiting for Travis to see the change. If you'd like to follow along go to "
TravisUrl="https://travis-ci.org/gbdubs/$ProjectName"
PrintLBlueLn "   $TravisUrl"
PrintBlue "You've waited (expect 15s): "
MostRecentStatus=$()
waiting=0
# TODO(grady) Fix this up so when the loop is broken it doesn't yell.
while [ -z $(travis whatsup --org | grep "$ProjectName " | grep "(errored|passed)" -E) ]
do
  PrintLBlue "[${waiting}s] "
  sleep 5s
  waiting=$(expr $waiting + 5)
done
ValidationStatus=$(travis whatsup | grep "$ProjectName" | head)
if [[ $ValidationStatus == *" passed: "* ]]
then
  PrintGreenLn "Successful Build."
else
  PrintRedLn "\nSomething Went Wrong. Check it out here: $TravisUrl"
  exit 1
fi

# TODO(grady) Dedupe this with the other validation code above
InvokeResultFile="aws_lambda_invoke_result.txt"
PrintBlue "Attempting to call Lambda on AWS... "
PayloadInput="Sent request at $(date)"
Payload="{\"Input\": \"$PayloadInput\"}"
AwsLambdaInvokeCommand="aws lambda invoke \
--function-name $FirstLambdaFullName \
--payload '$Payload' \
$InvokeResultFile"
AwsLambdaInvokeCommandResult="$(eval $AwsLambdaInvokeCommand)"
PrintGreenLn "Done."
InvocationStatusCode=$(ExtractFieldFromJsonResult "StatusCode" "$AwsLambdaInvokeCommandResult")
PrintLBlueLn "  Status = $InvocationStatusCode"
InvocationResult=$(cat "$InvokeResultFile")
rm "$InvokeResultFile"
InvocationExpectation="\"$ModifiedMessage $FirstLambdaName! request.Input=$PayloadInput\""
if [ "$InvocationResult" == "$InvocationExpectation" ]
then
  PrintLBlueLn "  Lambda response was as expected."
  PrintLBlueLn "    Expected : $InvocationExpectation"
  PrintLBlueLn "    Actual   : $InvocationResult"
else
  PrintRedLn "  Lambda response was not as expected."
  PrintRedLn "    Expected : $InvocationExpectation"
  PrintRedLn "    Actual   : $InvocationResult"
  exit
fi
