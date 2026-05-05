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
