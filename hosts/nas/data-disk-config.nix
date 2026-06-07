/**
  List of one or more disks that comprise the hosts zdata_<hostname> zpool.
  A user-facing host's zdata pool will consist of one or two disks.
  A server host's zdata pool may contain many mirrored vdevs:
    -> In this case, it is acceptable to provide just the disks for the first
       mirrored vdev.
    -> For this kind of host with large storage, dataDisks will only be used
       with "just format-data-disks" on initial host zdata pool creation.
*/
{
  custom.system.zfs.dataDisks = [
    "/dev/disk/by-id/wwn-0x5000cca2faf22259"
    "/dev/disk/by-id/wwn-0x5000cca418c6f46f"
  ];
}

