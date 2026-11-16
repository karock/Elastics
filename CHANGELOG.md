# Changelog

Releases of this fork (com.audiomack.Elastics). Versions before 1.7 are the
original Elastics by Tundra Bot.

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
