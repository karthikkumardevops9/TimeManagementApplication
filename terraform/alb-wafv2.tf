resource "aws_wafv2_web_acl" "WafWebAcl-alb" {
  name = "alb_WAF_Common_Protections"
  scope = "REGIONAL"

  default_action {
    allow {
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name = "alb_WAF_Common_Protections"
    sampled_requests_enabled = true
  }

  rule {
    name = "AWSManagedRulesCommonRule"
    priority = 0
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "AWSManagedRulesCommonRule"
      sampled_requests_enabled = true
    }
  }
  rule {
    name = "AWSManagedRulesKnownBadInputsRule"
    priority = 1
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "AWSManagedRulesKnownBadInputsRule"
      sampled_requests_enabled = true
    }
  }
  rule {
    name = "AWSManagedRulesAmazonIpReputation"
    priority = 2
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "AWSManagedRulesAmazonIpReputation"
      sampled_requests_enabled = true
    }
  }
  rule {
    name = "AWSManagedWafRule4"
    priority = 4
    override_action {
      none {
      }
    }
    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "AWSManagedWafRule4"
      sampled_requests_enabled = true
    }
  }
}


resource "aws_cloudwatch_log_group" "WafWebAclLoggroup-alb" {
  name              = "aws-waf-logs-wafv2-web-acl-alb"
  retention_in_days = 30
}



resource "aws_wafv2_web_acl_logging_configuration" "WafWebAclLogging-alb" {
  log_destination_configs = [aws_cloudwatch_log_group.WafWebAclLoggroup-alb.arn]
  resource_arn            = aws_wafv2_web_acl.WafWebAcl-alb.arn
  depends_on = [
    aws_wafv2_web_acl.WafWebAcl-alb,
    aws_cloudwatch_log_group.WafWebAclLoggroup-alb
  ]
}

resource "aws_wafv2_web_acl_association" "WafWebAclAssociation" {
  resource_arn = aws_lb.ecs_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.WafWebAcl-alb.arn
  depends_on = [
    aws_wafv2_web_acl.WafWebAcl-alb,
    aws_cloudwatch_log_group.WafWebAclLoggroup-alb
  ]
}