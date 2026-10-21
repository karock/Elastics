# Elastics

Monitor your AWS EC2 instances from your Mac menubar.

This is an unofficial, updated fork of [Elastics](https://github.com/tundrabot/Elastics)
by Dmitri Goutnik (Tundra Bot), which is no longer maintained. Questions and issues
about this fork belong [here](https://github.com/karock/Elastics/issues), not with
the original author.

Changes from Elastics 1.6:

- Native Apple Silicon (universal) build for macOS 13 and later; builds with
  current Xcode without CocoaPods; Mac App Store receipt validation removed
- AWS Signature Version 4, current EC2 API version, current region list
- Instance details: lifecycle, state reason, private IP, storage (EBS volumes and
  instance store)
- Instance search at the top of the menu (focused when the menu opens)
- Dark Mode fixes and modern menu bar icon

## AWS permissions

Elastics only reads data. Give it its own IAM user (or role) with just these
permissions rather than keys for a broadly privileged user:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ElasticsReadOnly",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeInstanceTypes",
        "cloudwatch:GetMetricStatistics"
      ],
      "Resource": "*"
    }
  ]
}
```

| Permission | Used for |
|---|---|
| `ec2:DescribeInstances` | Instance list and details (required) |
| `cloudwatch:GetMetricStatistics` | CPU chart and min/max/average |
| `ec2:DescribeVolumes` | EBS volume size and type in Storage (without it, volume IDs are shown) |
| `ec2:DescribeInstanceTypes` | Instance store disks in Storage (without it, they're not shown) |

These Describe/Get actions don't support resource-level restrictions, so
`"Resource": "*"` is required. To limit Elastics to particular regions, add a
condition such as:

```json
"Condition": { "StringEquals": { "aws:RequestedRegion": ["us-east-1", "us-west-2"] } }
```

Create an access key for that user, add it in Elastics Preferences, and rotate it
periodically. The key is stored in your login keychain.

## Building

```
xcodebuild -project Elastics.xcodeproj -target Elastics -configuration Release \
  SYMROOT="$PWD/build" OBJROOT="$PWD/build/obj"
```

The app is built to `build/Release/Elastics.app` and signed to run locally.

## License

MIT, see [LICENSE](LICENSE).
