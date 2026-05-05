# State-safe migration blocks for resources that move between modules without
# changing the live infrastructure.

moved {
  from = module.build_notifier_subscription.aws_cloudwatch_event_rule.this
  to   = module.codebuild_project.module.build_notifier_subscription[0].aws_cloudwatch_event_rule.this
}

moved {
  from = module.build_notifier_subscription.aws_cloudwatch_event_target.lambda
  to   = module.codebuild_project.module.build_notifier_subscription[0].aws_cloudwatch_event_target.lambda
}

moved {
  from = module.build_notifier_subscription.aws_lambda_permission.eventbridge
  to   = module.codebuild_project.module.build_notifier_subscription[0].aws_lambda_permission.eventbridge
}

moved {
  from = aws_iam_role.codebuild_role
  to   = module.codebuild_terraform_role.aws_iam_role.this
}

moved {
  from = aws_iam_role_policy.codebuild_policy
  to   = module.codebuild_terraform_role.aws_iam_role_policy.this
}
