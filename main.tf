provider "aws" {
  alias  = "source"
  region = "us-east-1"
}

provider "aws" {
  alias  = "destination"
  region = "us-west-2"
}

# Destination Bucket
resource "aws_s3_bucket" "dest_bucket" {
  provider      = aws.destination
  bucket        = "my-crr-dest-bucket-123456"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "dest_versioning" {
  provider = aws.destination
  bucket   = aws_s3_bucket.dest_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Source Bucket
resource "aws_s3_bucket" "source_bucket" {
  provider      = aws.source
  bucket        = "my-crr-source-bucket-123456"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "source_versioning" {
  provider = aws.source
  bucket   = aws_s3_bucket.source_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# IAM Role for Replication
resource "aws_iam_role" "replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "s3.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for Replication
resource "aws_iam_role_policy" "replication_policy" {
  name = "s3-replication-policy"
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
        ],
        Resource = [
          aws_s3_bucket.source_bucket.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectLegalHold",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectRetention"
        ],
        Resource = "${aws_s3_bucket.source_bucket.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = "${aws_s3_bucket.dest_bucket.arn}/*"
      }
    ]
  })
}

# Replication Configuration
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.source
  bucket   = aws_s3_bucket.source_bucket.id
  role     = aws_iam_role.replication_role.arn

  rule {
    id     = "replication-rule"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket        = aws_s3_bucket.dest_bucket.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
  depends_on = [aws_s3_bucket_versioning.source_versioning, aws_s3_bucket_versioning.dest_versioning]
}



