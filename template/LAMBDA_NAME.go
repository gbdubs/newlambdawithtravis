package main

import (
  "fmt"
  "context"
  "github.com/aws/aws-lambda-go/lambda"
)

type LAMBDA_NAME_UCRequest struct {
  Input string `json:"input"`
}

func HandleRequest(ctx context.Context, request LAMBDA_NAME_UCRequest) (string, error) {
  return fmt.Sprintf("This is the lambda LAMBDA_NAME! request.Input=%s", request.Input), nil
}

func main() {
  lambda.Start(HandleRequest)
}
