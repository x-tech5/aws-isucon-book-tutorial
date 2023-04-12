# K6 Scenario

ISUCON本（[達人が教えるWebパフォーマンスチューニング　〜ISUCONから学ぶ高速化の実践](https://www.amazon.co.jp/dp/B0B1Z9ZMY6/)）の第3章・第4章をもとにしています

# Usage

## accounts.jsonに記載のユーザを利用 **しない** 場合

書籍のとおり

```sh
cd src/scenario
k6 run integrated.js
```

## accounts.jsonに記載のユーザを利用 **する** 場合

環境変数 `ISU_USE_ACCOUNTS` を付与してk6を実行する

```sh
cd src/scenario
env ISU_USE_ACCOUNTS=y k6 run integrated.js
```
