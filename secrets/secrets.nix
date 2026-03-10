let
  admin = "age1he5a94rrdvr88vetyltxjz5xckvgm69j0h5uaq27kj48a8szfvtscn0rhw";
  nix-k3s-01 = "age1ps2hmsqze4h2g68vm7p4vmzn7r476hfef6aa0cmllqdqhes8jp5q95xcux";
  nix-k3s-02-gpu = "age1qlczh925nuwa9k0pqlrksxd3w00kffxjnpna4ze4lk7cmp5h9g8qkq9cnt";

  allSystems = [ nix-k3s-01 nix-k3s-02-gpu ];
  allKeys = [ admin ] ++ allSystems;
in
{
  "k3s_token.age".publicKeys = allKeys;
  "cloudflare_api_token_9rv.age".publicKeys = [ admin nix-k3s-01 ];
  "cloudflare_api_token_larsolo.age".publicKeys = [ admin nix-k3s-01 ];
}
