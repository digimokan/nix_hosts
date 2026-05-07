{ hostName, ... }: {
  # Derive primary hostName from blueprint ./hosts/dir
  networking.hostName = hostName;
}

