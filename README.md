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
- Connect with AWS Systems Manager Session Manager (SSM) as well as SSH and RDP
- Dark Mode fixes and modern menu bar icon

What changed in each release is in [CHANGELOG.md](CHANGELOG.md).

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

## Sharing instance details

Each instance's details start with its name, so a screenshot of just the details
says which instance it is. **Copy Details as Image** at the bottom of the details
puts a picture of them (including the CPU chart, in the current light or dark
appearance) on the clipboard, ready to paste into Slack; hold Option for
**Copy Details as Text**.

## Demo mode (for screenshots)

Demo mode shows a made-up fleet (about 20 instances across three regions, with
VPCs, tags, Auto Scaling groups, Spot and Windows instances, volumes and CPU charts)
and two example accounts, without contacting AWS or reading the keychain:

```
defaults write com.audiomack.Elastics-Preferences demoMode -bool YES   # on
defaults delete com.audiomack.Elastics-Preferences demoMode            # off
```

Quit and reopen Elastics after switching. All names, IDs and addresses are
invented (IPs from private and documentation ranges). Grouping and other settings
you change while in demo mode are kept afterwards.

## Connecting with Session Manager (SSM)

Every running instance has **Connect (SSM)...** next to Connect (SSH) or (RDP). It
opens a terminal (Terminal or iTerm, as set in Preferences) and runs:

```
aws ssm start-session --target <instance-id> --region <region> [--profile <profile>]
```

This uses the AWS CLI's own credentials, not the access key you gave Elastics (which
is never put in the command, where it would end up in shell history). Set the
profile under **AWS CLI profile** in Preferences > Connections, or per account in
the account sheet; leave it empty to use the AWS CLI's default (`AWS_PROFILE` or
`default`).

You need:

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html),
  both on the `PATH` of your login shell (the one the terminal opens)
- An instance that is managed by Systems Manager (SSM Agent running, and an
  instance profile such as `AmazonSSMManagedInstanceCore`). Elastics doesn't check
  this; for an unmanaged instance the error appears in the terminal.
- For the AWS CLI profile's user or role, permission to start and end sessions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ssm:StartSession",
      "Resource": [
        "arn:aws:ec2:*:*:instance/*",
        "arn:aws:ssm:*:*:document/SSM-SessionManagerRunShell"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "ssm:TerminateSession",
      "Resource": "arn:aws:ssm:*:*:session/${aws:userid}-*"
    }
  ]
}
```

Narrow `instance/*` to particular instances (or add a tag condition) as needed.

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
