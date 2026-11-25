# ---------------------------------------------------------------
# Logging centralizado: os containers enviam logs para o CloudWatch Logs
# ---------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  #checkov:skip=CKV_AWS_158:Logs criptografados pela chave padrão do CloudWatch; KMS dedicado fica como melhoria futura
  #checkov:skip=CKV_AWS_338:Retenção de 14 dias (configurável) é suficiente para o projeto acadêmico
  name              = local.log_group
  retention_in_days = var.log_retention_days
}

# Métrica derivada dos logs JSON: conta respostas 5xx da API
resource "aws_cloudwatch_log_metric_filter" "api_5xx" {
  name           = "${local.name}-api-5xx"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "{ $.status >= 500 }"

  metric_transformation {
    name          = "Api5xx"
    namespace     = "DevOpsNaPratica"
    value         = "1"
    default_value = "0"
  }
}

# ---------------------------------------------------------------
# Alertas: notificação por e-mail via SNS
# ---------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name}-cpu-alta"
  alarm_description   = "CPU da EC2 acima de 80% por 10 minutos"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { InstanceId = aws_instance.app.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "instance_status" {
  alarm_name          = "${local.name}-status-check"
  alarm_description   = "Falha no status check da EC2"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { InstanceId = aws_instance.app.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name}-api-erros-5xx"
  alarm_description   = "API retornando erros 5xx"
  namespace           = "DevOpsNaPratica"
  metric_name         = "Api5xx"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
