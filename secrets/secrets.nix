let
  lars = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDQhnTT3Gar1zCfmbvd5pJs4hLry69kvq6AelEhbaAFs stolpela@9rv.org";
  # nix-k3s-01 = "ssh-ed25519 .";
  # nix-k3s-02-gpu = "ssh-ed25519 .";
in
{
  "k3s-token.age".publicKeys = [
    lars
    # nix-k3s-01
    # nix-k3s-02-gpu
  ];
}
