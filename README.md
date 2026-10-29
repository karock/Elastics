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
- Optional grouping of the instance list into submenus, and a Tags submenu per instance
- Instance ID, AMI, Auto Scaling group and EBS volume rows open the AWS Console
  (hold Option to copy the ID instead)
- Dark Mode fixes and modern menu bar icon

## Grouping instances

Long instance lists can be grouped into submenus. In Preferences > General, choose
**Group instances**:

| Mode | Groups by |
|---|---|
| By VPC | The VPC's Name tag ("Default VPC" if unnamed; the VPC ID until names load) |
| By name prefixes | The longest prefix from your comma-separated list that the name starts with (ignoring case), e.g. `Prod, Dev, Staging` |
| By automatic name prefix | The text before the first `-`, `_`, `.` or space (or the whole name), when at least two instances share it (`prod`, `prod-web-1`, `prod-db-1` -> `prod`) |
| By tag | The value of a tag you name, e.g. `Environment`, or `aws:autoscaling:groupName` for Auto Scaling groups |

Instances that don't fit a group stay in the main list below the groups. Separately,
**Put stopped instances in a "Stopped" submenu** collects stopped instances in one
group at the bottom, and **Put terminated instances in a "Terminated" submenu** does
the same for terminated ones (when they aren't hidden altogether). Searching always
shows a flat list of all matches.

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
        "ec2:DescribeVpcs",
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
| `ec2:DescribeVpcs` | VPC names when grouping by VPC (without it, groups show VPC IDs) |

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

The app is built to `build/Release/Elastics.app`, universal (Apple Silicon and
Intel), for macOS 13 and later.

### Signing

By default the app is signed to run locally: it works on the Mac that built it,
but macOS asks again for keychain access after every rebuild, and other Macs
won't open it without a security override.

To sign with your own certificate:

```
scripts/configure-signing.sh
```

This finds a "Developer ID Application" certificate in your keychain (or else an
"Apple Development" one) and writes `Signing.local.xcconfig`, which is not
committed. Pass part of a certificate name to choose one, or `--reset` to go back
to the local signature.

- **Apple Development** certificate: builds keep the same signature, so keychain
  "Always Allow" sticks across rebuilds, but they are for your own Macs only.
- **Developer ID Application** certificate: builds can be notarized and given to
  others. Store your notarization credentials once:

  ```
  xcrun notarytool store-credentials elastics-notary \
    --apple-id you@example.com --team-id YOURTEAMID --password <app-specific-password>
  ```

  then run `scripts/release.sh`, which builds, verifies, notarizes, staples and
  writes `build/dist/Elastics-<version>.zip`.

## License

MIT, see [LICENSE](LICENSE).
