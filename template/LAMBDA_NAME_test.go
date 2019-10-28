package main

import "testing"

func TestHandlePopulatedRequest(t *testing.T) {
  var request LAMBDA_NAME_UCRequest
  request.Input = "HelloWorld!"
  
  msg, err := HandleRequest(nil, request)
  
  if err != nil {
    t.Errorf("Error was not nil!")
  }
  assertEqual(t, msg, "This is the lambda LAMBDA_NAME! request.Input=HelloWorld!")
}

func assertEqual(t *testing.T, s1 string, s2 string) {
  if s1 != s2 {
    t.Errorf("ERROR: Strings Don't Match: [%s] [%s]", s1, s2)
  }
}
