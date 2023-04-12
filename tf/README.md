**Note:**

かなりイイ感じのスペックのインスタンスを使うので **使わないときはstop** しましょう。

全部終わると：

- SSM経由でSSHで各インスタンスにログインできる
- AWS Management Consoleなどを利用して、X-Ray（or CloudWatch）でトレースが確認できる
- AWS Management Consoleなどを利用して、CloudWatch でメトリクスが確認できる
    - インスタンスメトリクスの解像度は粗いので、カスタムメトリクスとして登録されるホストメトリクスを併用するとよいでしょう

---

```
terraform init
terraform plan
terraform apply
```

- SSMでログインできます
- インスタンス生成時点でisuconユーザに特定のSSHログイン用公開鍵を設置する場合はapply時にvariableを指定する
    - SSM経由のSSHでログインできるようになります

```sh
terraform apply -var pubkey_url="https://github.com/netmarkjp.keys"
```

```
Host aws-isucon-book-tutorial-webapp
    HostName i-XXXXXXXXXXXXXXXXX
    User isucon
    ProxyCommand sh -c "aws --profile aws-isucon-book-tutorial ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
    ForwardAgent yes

Host aws-isucon-book-tutorial-benchmarker
    HostName i-YYYYYYYYYYYYYYYYY
    User isucon
    ProxyCommand sh -c "aws --profile aws-isucon-book-tutorial ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
    ForwardAgent yes
```