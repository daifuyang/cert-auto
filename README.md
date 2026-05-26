# 证书自动签发与上传 (cert-auto)

Automated HTTPS certificate issuance via ACME DNS-01 and upload to Aliyun CAS.

## 资产概览

### 阿里云账号

| 用途 | Profile | AccessKeyId |
|------|---------|-------------|
| DNS 验证 | `personal` | LTAI5tGaLGzAjDMKHKCajB8q |
| CAS 上传 | `enterprise` | LTAI5tQCSmUopAWN5cd4ZzKz |

### 个人账号 DNS 域名 (personal)

| 域名 | 用途 |
|------|------|
| yugong.tech | |
| daifuyang.com | |
| dtxigua.com | |
| dtxigua.cn | |
| zerocmf.cn | |
| zerocmf.com | 主域名 |
| vlog-v.com | |
| iximei.cn | |
| hji5.com | |

### 企业账号 DNS 域名 (enterprise)

| 域名 | 用途 |
|------|------|
| genlabs.cc | |
| yugongsoft.cn | |
| yugongsoft.com | |
| mashangdian.cn | |
| codecloud.ltd | |

### 企业 CAS 证书

| 证书名 | 域名 | 签发方 | 到期日 | 状态 |
|--------|------|--------|--------|------|
| demo-test-enterprise | demo.zerocmf.com | Let's Encrypt | 2026-08-23 | 有效 |

### Qiniu CDN 证书

| 域名 | Bucket | 证书 | 到期日 | 状态 |
|------|--------|------|--------|------|
| cdn.zerocmf.com | ai-code | cdn-zerocmf-com-new | 2026-08-24 | ✅ https |
| static.zerocmf.com | yg-yishan | static-zerocmf-com-auto | 2026-06-24 | ✅ https |
| cdn.vlog-v.com | vlog | cdn-vlog-v-com-new | 2026-09-02 | ✅ https |

---

## 自动化

### Qiniu CDN 证书自动续期 (cron)

```bash
# 每日 03:00 检查，过期前30天自动续期
0 3 * * * cd /home/dfy/workspace/tools/aic && node dist/index.js cert:renew >> ~/.logs/cert-renew.log 2>&1

# acme.sh 自动续期 (已有)
50 5 * * * "/home/dfy/.acme.sh"/acme.sh --cron --home "/home/dfy/.acme.sh"
```

```bash
# 查看续期日志
cat ~/.logs/cert-renew.log

# 手动检查哪些证书需要续期
aic cert:renew --dry-run

# 自定义检查天数 (如过期前60天)
aic cert:renew --days 60 --dry-run
```

### GitHub Actions (Aliyun CAS)

- **手动触发**: Actions → Cert Auto Issue & Upload → Run workflow
- **定时任务**: 每日 03:00 UTC 自动执行

---

## aic 命令参考

```bash
# Qiniu CDN 证书
aic cert:renew --dry-run    # 检查需要续期的证书
aic cert:renew              # 执行续期
aic cert:list               # 列出所有证书
aic cert:bind <domain> <certId>  # 绑定证书到域名

# DNS 操作 (personal profile)
aic dns:list <domain> -p personal
aic dns:add <domain> <rr> <type> <value> -p personal

# CAS 操作 (enterprise profile)
aic aliyun-cert:list -p enterprise
aic aliyun-cert:upload <name> <certFile> <keyFile> -p enterprise

# 证书签发
aic cert:issue <domain> -d aliyun -p personal
```

---

## 配置文件

- aic 配置: `~/.config/aic/config.toml`
- 域名配置: `./config/domains.env`
