# packer
add env.sh file
```
export VAULT_TOKEN='s.xxxxxxxxxxxxxxx''
export VAULT_ADDR='http://xx.xx.xx.xx:8200'
```

debug
```
export PACKER_LOG=1
packer build --debug . 
```

```
packer init .
packer build .
```
