This is the new documentation on how to use LUKS with TPM enabled on RHEL7.

As of 2015-11-02, TrustedGRUB2 1.2.1 + tpm-luks + tpm-tools is working on HP desktop with TPM enabled.

As of 2016-02-01, installed on HP Apollo production servers, with two additions: reuse TPM NVRAM index as TPM is not big enough for 24 disks + tpm-luks-svc to open devices after boot time, for data disks, to prevent grub.cfg modification - see C. Notes.

Old documentation can be found here: [README_OLD]

## Introduction

This project objective is to save the LUKS keys in the TPM NVRAM on RHEL7 systems, **and only RHEL7**.

To acomplish this, we will use:
* [trousers]: allows to read and write the TPM
* [tpm-tools]: a utility that ease the use of the TPM
* [tpm-luks]: a dracut extension that reads the TPM NVRAM to get the key to use by LUKS
* [TrustedGRUB2]: a secure boot loader that fills PCR based on boot configuration

Unfortunately, the default **tpm-tools** you can find in the RHEL repo does not work, **tpm-luks** is not compatible with RHEL7 and **TrustedGRUB2** is not available as an RPM.

Note that **trousers** is only necessary because we need the trousers-devel to build tpm-tools.

So, you will have to build your own RPMs, but this is very easy after all.

## A. Building

You will find in `xtra/rhel7` the necessary scripts to compile and build your own RPMs of **tpm-tools**, **tpm-luks** and **TrustedGRUB2**.

It is recommended to start with a fresh minimal install of rhel7. This is one possible procedure to do so:
* create a new virtual box virtual machine with 512MB of RAM and 8GB of disk
* install rhel from the rhel 7.1 iso cdrom you can download from redhat.com
* configure network so it can access the internet
* mount the cdrom to /mnt/cdrom: `mkdir /mnt/cdrom ; mount /dev/sr0 /mnt/cdrom`
* create a cdrom repo:
```
cat <<EOF > /etc/yum.repos.d/cdrom.repo
[cdrom]
name=cdrom
baseurl=file:///mnt/cdrom
enabled=1
gpgcheck=0
EOF
```

* verify it works: `yum update`
* install git : `yum install -y git`

You can now configure the system using the scripts in xtra/rhel7 folder:
```
git clone https://github.com/momiji/tpm-luks
cd tpm-luks/xtra/rhel7
./install.sh -d
sudo su - makerpm
git clone https://github.com/momiji/tpm-luks
cd tpm-luks/xtra/rhel7
./install.sh -d
```

When successfull, you can start building the RPMS:
```
./build_trousers.sh -d
./build_tpm-tools.sh -d
./build_tpm-luks.sh -d
./build_trustedgrub2.sh -d
```

## B. Installing

You need a RHEL7 system with TPM hardware, **installed without EFI**, because TrustedGRUB2 is not compatible with EFI.
System partitions must be encrypted at install with LUKS.

Remember you should only use basic ascii characters for TPM AUTH and OWNER passwords, like `A-Z`, `a-z`, `0-9`, plus some other chars that do not need to be escaped in bash shell. Do not use characters like `'` or `"`.

Before installing, you need to copy on the server the 3 packages we build in previous section: **tpm-tools**, **tpm-luks** and **TrustedGRUB2**.

From there, you can simply call the deploy.sh script, it will install and configure the system:
* configure yum to not automatically update these 3 packages
* install the packages
* configure the packages
```
curl https://raw.githubusercontent.com/momiji/tpm-luks/master/xtra/rhel7/deploy.sh -o deploy.sh
sh deploy.sh
```

You can now generate new LUKS keys and seal them:
```
tpm-luks-ctl init      to generate new LUKS keys and save them in the TPM NVRAM
tpm-luks-ctl backup    to dump the LUKS keys and backup them in a safe place
dracut --force         to update initramfs
reboot                 to verify it works and have all PCRs computed correctly
tpm-luks-ctl seal      to seal the TPM NVRAM
reboot                 to verify it restarts automatically
tpm-luks-ctl check     to be sure
```

For the first boot, keys are not sealed and no password is required.
For the second boot, keys are sealed and automatically read.

Remember that modifying the `/etc/tpm-luks.conf` requires to update the boot:
```
dracut --force`
```

## C. Notes

When initialized or unsealed, the TPM NVRAM is readable directly without having to enter a password. If you want an AUTH password, you can use the `-a` or `--auth-password` option. For the OWNER password, you can use `-o` or `--owner-password`.

If you want to use over PCRs than the defaults, you can modify them directly in the script `/usr/sbin/tpm-luks-gen-tgrub2-pcr-values`, or change the
scripts defined for each devices in `/etc/tpm-luks.conf`.

You can check if tpm-luks is configured correctly:
* `tpm-luks-ctl check`

If you want to unseal the TPM, before a reboot for example, remember to seal after the reboot:
* unseal: `tpm-luks-ctl unseal`
* `reboot`
* seal: `tpm-luks-ctl seal`

To add new LUKS partitions at boot time:
* modify `/etc/default/grub` file with new partitions info
* unseal: `tpm-luks-ctl unseal`
* add new partitions: `tpm-luks-ctl init`
* save backup: `tpm-luks-ctl backup`
* update grub: `grub-mkconfig -o /boot/grub/grub.cfg`
* update iniramfs: `dracut --force`
* reboot: `reboot`
* seal: `tpm-luks-ctl seal`
* `reboot` to verify everything is ok

To add new LUKS partitions (i.e. for data) just after boot time, with tpm-luks-svc - beware, the size of TPM NVRAM is limited, so it might be usefull to use the same TPM NVRAM for all data disks -- here I'm using index 1:
* format all data disks using `cyptsetup luksFormat` with a very simple text password for example, and get it's UUID
```
echo -n "abc" > luks.key
cryptsetup luksFormat /dev/sdx --key-file luks.key
cryptsetup luksDump /dev/sdx | grep UUID: | awk '{print $2}'
```
* add the new disks in `/etc/crypttab` with `noauto` option
```
data0x UUID=x*** none noauto
```
* add new paritions with index 1: `tpm-luks-ctl init -i 1`
* save backup: `tpm-luks-ctl backup`
* start service automatically: `chkconfig --add tpm-luks-svc`
* unseal: `tpm-luks-ctl unseal`
* reboot: `reboot`
* seal: `tpm-luks-ctl seal`
* reboot: `reboot`

[README_OLD]: README_OLD.md
[trousers]: http://sourceforge.net/projects/trousers/
[tpm-tools]: http://sourceforge.net/projects/trousers/
[tpm-luks]: https://github.com/shpedoikal/tpm-luks/
[TrustedGRUB2]: https://github.com/Sirrix-AG/TrustedGRUB2/
[mock]: http://fedoraproject.org/wiki/Projects/Mock
