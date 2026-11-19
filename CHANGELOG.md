# Changelog

Releases of this fork (com.audiomack.Elastics). Versions before 1.7 are the
original Elastics by Tundra Bot.

## 1.10 (200)

- **Connect (SSM)** for every running instance, Linux or Windows, alongside
  Connect (SSH) or (RDP). It runs `aws ssm start-session` in Terminal or iTerm,
  using the AWS CLI's credentials (an **AWS CLI profile** can be set in Preferences
  and per account); Elastics' own access key is never put in the command. Needs
  the AWS CLI v2 and the Session Manager plugin. See "Connecting with Session
  Manager (SSM)" in the README.
- Fixed: the SSH user name of a newly added account wasn't saved.
- Fixed: saving an account in Preferences made Elastics quit unexpectedly (or, in
  test builds, show "Untitled" with an AWS authorization error): the running app
  couldn't read the changed keychain item. Elastics now reopens itself to pick it
  up. Long error messages in the menu are no longer cut off.

## 1.9 (190)

- **Instance name at the top of the details.** Each instance's details now start
  with its name (or ID) and state icon, so a screenshot of just the details says
  which instance it is. Long names wrap instead of widening the menu.
- **Copy Details as Image.** A new item at the bottom of the details copies a
  picture of them (laid out like the menu, including the CPU chart, in the current
  light or dark appearance) to the clipboard, ready to paste into Slack. Hold
  Option for **Copy Details as Text**.
- **Demo mode** for screenshots: a made-up fleet of instances and accounts, with
  no AWS access. See "Demo mode" in the README.
- Detail rows are a little wider so full-length instance and image IDs fit on one
  line.
- The Tags row shows its count as "Tags (n)".

## 1.8 (180)

- **Grouping instances** by VPC, name prefixes (listed or automatic) or a tag,
  with optional "Stopped" and "Terminated" groups. Searching shows a flat list.
- **Tags** submenu in each instance's details; click a tag to copy its value.
- **AWS Console links** for the instance, image, Auto Scaling group and EBS
  volumes; hold Option to copy the ID instead.
- Requires ec2:DescribeVpcs for VPC names (see "AWS permissions" in the README).

## 1.7 (170)

First release of the modernized app:

- Universal (Apple Silicon and Intel) build for macOS 13 and later, signed and
  notarized.
- AWS Signature Version 4 and all current regions.
- Private IP shown, and used for SSH/RDP when there's no public address.
- Lifecycle, State Reason, storage (EBS volumes and instance store) in the
  details; search field in the menu.
- Security fixes (SSH/RDP command quoting, Hardened Runtime, keychain access).
- New bundle IDs; settings and accounts from the original app are imported once.
