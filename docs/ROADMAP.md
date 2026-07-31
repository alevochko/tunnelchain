# ROADMAP — Nodes & proxy import

**Проект:** TunnelChain  
**Связанные документы:** [FR.md](FR.md) · [AR.md](AR.md) · [ADR.md](ADR.md)

---

## Контекст

Сейчас импорт узлов ограничен:

- **Proxy:** только `vless://` (TCP + TLS/REALITY); остальные типы в UI disabled.
- **VPN:** WireGuard `.conf`; AmneziaWG импортируется, но полная поддержка в генераторе — в работе.
- **Импорт:** одна ссылка / один конфиг; подписочные URL (`https://…`) не поддерживаются.

Цель roadmap — последовательно расширить импорт и генератор sing-box, не ломая цепочки и split-routing.

---

## Фазы (порядок обязателен)

### Фаза 1 — Расширение поддержки VLESS-конфига

**Зачем:** реальные share-ссылки и Xray/sing-box JSON часто используют не только TCP REALITY.

| Область | Сейчас | Цель |
|--------|--------|------|
| Transport | TCP only | gRPC, WebSocket, HTTP/2, HTTPUpgrade |
| Security | TLS, REALITY | те же + корректный парсинг flow, fp, pbk, sid |
| Парсер `vless://` | отклоняет `transport != tcp` | принимать все транспорты, которые умеет sing-box |
| `hop_builder` / generator | TCP + TLS/REALITY | маппинг transport → outbound JSON по sing-box schema |
| UI Nodes | VLESS enabled | превью показывает transport/security; предупреждения для неподдерживаемого |

**Критерий готовности:** импорт и connect для VLESS TCP REALITY + минимум один альтернативный transport (например gRPC REALITY) из share-link и из raw JSON.

**Зависимости:** тесты в `config_generator_test`, парсер `vless_parser.dart`, `hop_builder.dart`.

---

### Фаза 2 — Подписочные ссылки (subscription URL)

**Зачем:** пользователи получают узлы пачкой с панели (v2rayN, 3x-ui, Marzban и т.д.), а не по одной ссылке.

| Область | Цель |
|--------|------|
| Импорт From URL | `https://` / `http://` subscription → fetch + decode (base64/plain) |
| Форматы | список `vless://` (и позже других схем) в одном ответе |
| UI | вкладка From URL / subscription; выбор узлов из списка перед сохранением |
| Безопасность | таймаут, размер ответа, без автo-update в фоне на первом этапе |
| Хранение | узлы как обычные profiles в `profiles.json` (без отдельного «провайдера») |

**Критерий готовности:** вставка subscription URL → превью списка узлов → импорт выбранных в каталог Nodes.

**Зависимости:** **Фаза 1** (иначе большинство узлов из подписки не подключится).

---

### Фаза 3 — Другие протоколы

**Зачем:** UI уже показывает Hysteria, Trojan, Shadowsocks, SOCKS, AmneziaWG — нужно довести до рабочего connect.

Приоритет внутри фазы (предварительно):

| Приоритет | Протокол | Заметки |
|-----------|----------|---------|
| P0 | **AmneziaWG** | jc/jmin/jmax в endpoint, sing-box-lx при active AWG |
| P1 | **Hysteria2** | популярен в подписках |
| P2 | Trojan, Shadowsocks | sing-box outbounds + парсеры URI |
| P3 | SOCKS5 / HTTP | как outer hop в цепочках |
| P4 | VMess / Tuic | по запросу, если встречаются в подписках |

Для каждого протокола: модель профиля → парсер URI/conf → `hop_builder` → тесты генератора → включить chip в **Add proxy** / **Add VPN**.

**Критерий готовности:** протокол enabled в UI, импорт, участие в chain, успешный connect в тестовом профиле.

**Зависимости:** **Фаза 1–2** для сценария «subscription → mixed nodes → chain».

---

### Фаза 4 — Profiles: быстрый выбор и файловый обмен

**Зачем:** сейчас смена профиля — только на вкладке Profiles; перенос настроек между Mac — вручную. На Status уже есть hero и routing summary, но нет быстрого переключения.

| Область | Сейчас | Цель |
|--------|--------|------|
| Status screen | активный профиль только в subtitle hero | **dropdown** рядом с hero / под статусом: список профилей, tap → `setActiveProfile`, без ухода со Status |
| Экспорт | нет | **Export to file…** — один профиль или все; JSON в согласованном формате (id, name, chain ref, routing, DNS) |
| Импорт | нет | **Import from file…** — drag & drop или file picker; превью перед merge; конфликты id → rename / replace / skip |
| Хранение | `profiles.json` | импорт добавляет/обновляет записи в том же store; экспорт не трогает runtime state |

**Критерий готовности:**

- на Status выбранный в dropdown профиль становится active и отражается в hero subtitle + menu bar;
- экспортированный файл импортируется на другом инстансе без потери chain/routing rules;
- ошибки формата — понятный VerdictCard, без частичного silent corrupt.

**Зависимости:** нет жёсткой связи с фазами 1–3; можно делать параллельно. Для connect после импорта нужны валидные node refs в каталоге.

---

## Вне scope этого roadmap

- Маркетплейс / автообновление подписок по расписанию (можно отдельной фазой позже).
- urltest / балансировщики между узлами одной подписки.
- iOS / Android.

---

## Текущее состояние UI (Nodes)

```
Add proxy:  VLESS ✓  |  Hysteria, Hysteria2, Trojan, SS, SOCKS, HTTP — disabled
Add VPN:    WireGuard ✓  |  AmneziaWG — disabled
Import:     From URL | From clipboard | From config (+ drag & drop на config)
```

По мере закрытия фаз — снимать `disabled` и обновлять этот раздел.

---

## История

| Дата | Изменение |
|------|-----------|
| 2026-07-31 | Первая версия: фазы 1 → 2 → 3 (VLESS → subscriptions → other protocols) |
| 2026-07-31 | Фаза 4: dropdown профиля на Status, import/export профилей через файл |
