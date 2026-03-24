provider "aws" {
  region = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_iam_group" "helpdesk" {
  name = "helpdesk"
}

resource "aws_iam_group_policy_attachment" "vm_contributor" {
  group = aws_iam_group.helpdesk.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_policy" "custom_support" {
  name = "CustomSupportRequest"
  description = "A custom contributor role for support requests."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["support:*"]
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = ["support:AddCommunicationToCase"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "custom_support_attach" {
  group = aws_iam_group.helpdesk.name
  policy_arn = aws_iam_policy.custom_support.arn
}
