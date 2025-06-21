resource "aws_s3_bucket" "bucket_bovespa_raw" {
  bucket = var.bucket_name_bovespa_raw
}

resource "aws_s3_bucket" "bucket_bovespa_refined" {
  bucket = var.bucket_name_bovespa_refined
}


########################
### CRIANDO UMA ROLE ###
########################

resource "aws_iam_user" "generic_user" {
  name = "generic-user-${var.enviroment}"
}

resource "aws_iam_role" "generic_role" {
  name = "genereic-role-${var.enviroment}"

  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
    EOF
    }

resource "aws_iam_group" "generic_group" {
  name = "generic-group-${var.enviroment}"
}

resource "aws_iam_policy" "generic_policy" {
  name        = "generic-policy-${var.enviroment}"
  description = "A generic policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "generic-attach" {
  name       = "generic-attachment-${var.enviroment}"
  users      = [aws_iam_user.generic_user.name]
  roles      = [aws_iam_role.generic_role.name]
  groups     = [aws_iam_group.generic_group.name]
  policy_arn = aws_iam_policy.generic_policy.arn
}