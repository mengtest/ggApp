sh.addShard("shard0001/111.230.108.129:27017")
sh.addShard("shard0001/111.230.108.129:27018")
sh.addShard("shard0001/111.230.108.129:27019")
sh.addShard("shard0002/111.230.108.129:27027")
sh.addShard("shard0002/111.230.108.129:27028")
sh.addShard("shard0002/111.230.108.129:27029")
sh.addShard("shard0003/111.230.108.129:27037")
sh.addShard("shard0003/111.230.108.129:27038")
sh.addShard("shard0003/111.230.108.129:27039")
printjson(sh.status())
