# VLESS + Reality 一键脚本

基于 Xray 内核的 VLESS + Reality 一键安装与管理脚本。

## 一键安装

```bash
curl -fsSL https://raw.githubusercontent.com/rainbowgag/Reality-/master/reality.sh -o reality.sh && bash reality.sh
```

安装过程中可以交互设置：

- 节点名称（默认使用服务器公网 IP）
- SNI 域名（默认根据服务器 IP 所属国家自动选择，仍可手动输入）
- 端口（默认 `443`）

UUID、Reality 公私钥、Short ID、Fingerprint 等参数每次创建都会随机生成。

## 默认 SNI 自动选择规则

脚本会检测服务器公网 IP 的归属国家/地区，并从对应国家的候选小众域名中，自动选择 TCP 443 延迟最低的域名作为默认 SNI。

| 国家/地区 | 候选域名 |
| --- | --- |
| 美国 | `computerhistory.org`、`www.exploratorium.edu`、`www.cmog.org`、`www.thehenryford.org`、`www.museumofplay.org`、`www.montereybayaquarium.org` |
| 英国 | `www.railwaymuseum.org.uk`、`www.scienceandmediamuseum.org.uk`、`www.wealddown.co.uk`、`www.rmg.co.uk`、`www.nationaltrust.org.uk` |
| 德国 | `www.technik-museum.de`、`www.phaeno.de`、`www.dasa-dortmund.de`、`www.museumfuernaturkunde.berlin`、`www.senckenberg.de` |
| 日本 | `www.kobe-oukoku.com`、`kyotomm.jp`、`www.tepia.jp`、`www.kaiyukan.com`、`www.ghibli-museum.jp` |
| 韩国 | `www.sciencecenter.go.kr`、`www.samsung.com` |
| 法国 | `www.cite-espace.com`、`www.musee-marine.fr`、`museedesconfluences.fr` |
| 新加坡 | `www.science.edu.sg`、`www.peranakanmuseum.nhb.gov.sg`、`www.nationalgallery.sg`、`www.gardensbythebay.com.sg` |
| 马来西亚 | `iamm.org.my`、`www.royalselangor.com`、`museumvolunteersjmm.com`、`www.gamudaland.com.my` |
| 台湾 | `beitoumuseum.org.tw`、`www.huashan1914.com`、`www.opentix.life`、`www.nmtl.gov.tw`、`www.ntm.gov.tw`、`www.ntmofa.gov.tw`、`www.nmp.gov.tw` |
| 香港 | `www.kfbg.org`、`hk.science.museum`、`www.hkmemory.hk`、`www.mplus.org.hk` |
| 其他国家/地区 | `lightnode.com`、`inet.ws` |

## 日常管理

安装完成后，在终端直接输入：

```bash
ry
```

即可打开管理菜单，支持：

1. 查看节点信息 / VLESS 链接 / 二维码
2. 查看 Xray 状态
3. 重启 Xray
4. 卸载节点（保留脚本和 `ry` 命令）
5. 完全卸载（节点 + 脚本 + `ry` 命令）

## 输出内容

- VLESS 分享链接
- 终端二维码
- Clash（单排横向）节点

## 目录说明

- Xray 配置：`/usr/local/etc/xray/config.json`
- 节点信息：`/usr/local/etc/reality/node.conf`
- 管理脚本：`/usr/local/bin/reality-manage.sh`
- 菜单命令：`/usr/local/bin/ry`

## 注意事项

- 请使用 root 权限运行。
- 若 443 端口被其他服务占用，脚本会提示确认，请根据实际情况选择。
- Reality 目标站点和端口为 `${SNI}:443`，请保持服务器能正常访问该目标。

## 推荐 VPS 商家

如需购买适合部署的 VPS，推荐使用 [莱卡云](https://www.lcayun.com/aff/MWLOCMDA)。

## 免责声明

本项目仅用于技术学习、研究与交流，使用者应遵守所在国家或地区的相关法律法规。

- 请勿将本项目用于任何违反当地法律法规、侵犯他人权益或危害网络安全的用途。
- 部署和使用本项目所产生的任何风险、责任及后果，均由使用者自行承担。
- 项目作者不对因使用本脚本而造成的直接或间接损失、法律责任或其他任何后果负责。
- 请在遵守法律法规和网络服务提供者条款的前提下使用本项目。
