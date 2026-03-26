provider "aws" {
  region = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_iam_user" "user1" {
  name = "az104-01a-u1"
}

resource "aws_iam_user" "user2" {
  name = "az104-01a-u2"
}

resource "aws_iam_group" "lab_group" {
  name = "az104-01a-g1"
}

resource "aws_iam_group_membership" "add_users" {
  name = "lab-membership"
  group = aws_iam_group.lab_group.name

  users = [
    aws_iam_user.user1.name,
    aws_iam_user.user2.name,
  ]
}
