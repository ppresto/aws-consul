resource "aws_iam_role" "consul_role" {
  name = var.role_name

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

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_instance_profile" "consul_profile" {
  name = "${var.role_name}-profile"
  role = aws_iam_role.consul_role.name
}

resource "aws_iam_role_policy" "getrole_policy" {
  name = "${var.role_name}-policy"
  role = aws_iam_role.consul_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Action": ["iam:GetRole"],
          "Effect": "Allow",
          "Resource": "*"
      }
  ]
}
EOF
}

# resource "aws_instance" "role-test" {
#   ami = "ami-0bbe6b35405ecebdb"
#   instance_type = "t2.micro"
#   iam_instance_profile = "${aws_iam_instance_profile.consul_profile.name}"
#   key_name = "mytestpubkey"
# }