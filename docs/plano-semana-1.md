# Plano de arranque — Semana 1 · Homelab Hub

**Versão:** 0.1 (rascunho para comentário) · **Data:** 11 nov 2026
**Estado:** aberto a comentários até ao kickoff
**Âmbito:** primeira sprint — provar o fluxo ponta a ponta, não construir o produto final

---

## 0. Como comentar este plano

- Comentário inline no PR que introduz este ficheiro (preferido).
- Ou uma issue com a label `plano`, uma por tema.
- Alterações de **scope** ou **horas**: propor em comentário. A tabela só muda depois de fecharmos a discussão, para não perdermos o histórico.
- Dúvidas que bloqueiem trabalho: marcar no comentário com `@` ao dono do módulo.

---

## 1. Objetivo da semana

No fim da semana 1, qualquer membro da equipa consegue, num PC limpo com WSL2 + Docker, correr:

```bash
cp .env.example .env   # preencher segredos
docker compose up -d
```

E assistir a este fluxo sem tocar em mais nada:

1. O n8n lê um email de uma **conta de teste**.
2. O Ollama (local) resume o email em português.
3. O resumo é enviado para um canal do **Discord**.
4. O resumo fica registado no **Postgres** e aparece no **painel**.

A demo de domingo são 5 minutos: mostrar o email a chegar, o resumo no Discord e o registo no painel. O resto é conversa.

**Critério de sucesso:** a demo corre duas vezes seguidas, a partir de `docker compose up`, sem passos manuais escondidos.

---

## 2. Fora de âmbito (semana 1)

Para proteger as 36 h, ficam explicitamente de fora:

- autenticação multiusador e contas no painel;
- deploy em cloud ou acesso fora da rede local;
- RAG, embeddings, fine-tuning ou histórico de conversas;
- suporte a Outlook/Microsoft Graph (só IMAP);
- ingestão de anexos, PDFs ou imagens;
- notificações em tempo real (o painel pode ter refresh manual);
- SLA, monitorização 24/7 e backups automáticos.

Se algum destes for essencial para a demo, dizer **antes** do kickoff — troca-se por outro item, não se soma.

---

## 3. Arquitetura da semana 1

Tudo corre no PC do Martim (WSL2 + Docker Desktop), numa única rede do compose:

```
                    PC do Martim — WSL2 + Docker
┌──────────────────────────────────────────────────────────────┐
│  docker compose                                              │
│                                                              │
│   ┌─────────────┐    IMAP     ┌──────────────────┐           │
│   │    n8n      │────────────▶│ Conta de teste   │  (Gmail)  │
│   │   :5678     │             └──────────────────┘           │
│   │             │──▶ Ollama :11434 ──▶ resumo               │
│   │             │──▶ Discord (webhook) ──▶ canal do grupo    │
│   │             │──▶ API :8000 ──▶ Postgres :5432            │
│   └─────────────┘                      ▲                     │
│          │                             │                     │
│          └── base interna do n8n ──────┘                     │
│                                        │                     │
│                          Painel :8501 ─┘  (lê a API)         │
└──────────────────────────────────────────────────────────────┘
```

| Serviço | Porta | Exposta ao host? | Nota |
|---|---|---|---|
| n8n | 5678 | sim (localhost) | UI e editor de workflows |
| Ollama | 11434 | sim (localhost) | API local de modelos |
| Postgres | 5432 | **não** | acesso via `docker compose exec postgres psql` |
| API | 8000 | sim (localhost) | adicionada pelo Afonso (M4) |
| Painel | 8501 | sim (localhost) | adicionado pelo Dani (M3) |

Decisões já tomadas (a confirmar na secção 10):

- **n8n** como motor de automação: evita escrever um worker de email do zero.
- **Ollama** local: privacidade e custo zero; o modelo default é leve para correr em CPU.
- **Postgres único**: base `n8n` para as tabelas internas, base `homelab` para a aplicação. Separação barata que evita colisões.
- **API FastAPI** entre o n8n e o Postgres: o n8n não escreve SQL diretamente; mantém o workflow simples e dá ao painel um contrato estável.
- **Painel Streamlit** read-only: menos horas de frontend, mais tempo para o fluxo principal.

**Restrições herdadas do roadmap do grupo** (PDF de referência, fora do repositório)

- 5–7 h por pessoa por semana (25–35 h no grupo); as fases 1 e 2 correm em paralelo.
- O PC do Martim (GTX 1660 Super, 6 GB) é o único que corre o Qwen 3 4B com qualidade; o PC do Afonso (4 GB) fica para modelos 1–3B. Por isso o Ollama da demo corre no PC do Martim.
- Sessão diária às 21h (10 min) e demonstração/retrospetiva ao domingo (30 min).
- Sem Kubernetes, sem fine-tuning e sem frontend elaborado: Docker Compose e uma UI simples chegam.

---

## 4. Módulos, donos e horas

Total: **36 h**. Cada módulo tem um dono único e um critério de aceitação verificável.

| ID | Módulo | Dono | Horas | Depende de |
|---|---|---|---|---|
| M1 | Infraestrutura base (compose, segredos, healthchecks) | Martim | 7 h | — |
| M2 | Workflow n8n (email → resumo → Discord/API) | Lourenço | 8 h | M1 |
| M3 | Esquema de dados + painel | Dani | 8 h | M1, contrato M4 |
| M4 | API + CI (backend) | Afonso | 7 h | contrato M3 |
| M5 | Registo de riscos + modelo de ameaças | Carlos | 6 h | arquitetura (§3) |
| | **Total** | | **36 h** | |

> **Nota de capacidade:** 36 h não inclui a demo/retrospetiva de domingo (30 min) nem revisões de PR. O plano assume que cada pessoa revê um PR por dia dentro das suas horas. Se houver atraso superior a 4 h, corta-se o painel para “dados seed” e mantém-se o fluxo ponta a ponta — essa é a prioridade.
>
> O roadmap do grupo assume 5–7 h/pessoa/semana (máximo 35 h). As 36 h estão 1 h acima do teto: ou o Carlos entrega a v0.1 do registo em 5 h, ou o grupo aceita explicitamente o desvio.

### M1 · Infraestrutura base — Martim (7 h)

**Entregáveis**
- `docker-compose.yml` com Postgres, n8n e Ollama (baseline já no repo).
- `.env.example` completo e `.env` ignorado pelo Git.
- Healthchecks, volumes nomeados, `restart: unless-stopped`.
- `db/init/00-create-app-db.sql` a criar a base `homelab`.
- Secção “Quickstart” no README: do zero ao n8n em menos de 30 min.
- Fixar as versões das imagens depois do primeiro arranque bem-sucedido.

**Critério de aceitação**
- `docker compose config` sem erros e `docker compose ps` com os três serviços `healthy`.
- `http://localhost:5678/healthz` responde 200.
- `curl http://localhost:11434/api/tags` responde 200.
- Nenhum segredo aparece em `git status` nem no histórico.
- Testado em WSL2 (Martim) e, se possível, num Linux nativo (Afonso).

**Risco principal:** ser o bloqueador de todos. Primeira entrega (compose a correr) até ao fim do dia 1, mesmo que o resto do módulo fique para depois.

### M2 · Workflow n8n — Lourenço (8 h)

**Entregáveis**
- Workflow importável em `workflows/01-resumo-emails-discord.json` (baseline já no repo).
- Credencial IMAP configurada na UI (nunca no ficheiro exportado).
- Prompt em português europeu, com limite de caracteres e instrução para dizer se exige ação.
- Envio para Discord via webhook e `POST` para a API (com `continue on fail` enquanto a API não existir).
- Tratamento de casos: inbox vazia, timeout do Ollama, webhook a devolver erro.
- Export final do workflow no PR.

**Critério de aceitação**
- Execução manual produz uma mensagem com menos de 2000 caracteres.
- Três execuções seguidas não geram duplicados no Postgres (dedupe por `message_id`).
- Inbox vazia termina sem erro vermelho no n8n.
- O workflow exportado importa noutra máquina sem perder nós (credenciais ficam a pedir seleção, como esperado).

**Depende de:** M1 (n8n e Ollama a correr). Pode começar pelo prompt e pela conta de teste antes de M1 fechar.

### M3 · Esquema de dados + painel — Dani (8 h)

**Entregáveis**
- Migrações idempotentes em `db/migrations/` para a tabela `summaries` (ver contrato §6).
- Script de seed com 5–10 registos fictícios.
- Painel Streamlit: últimos 20 resumos, filtro por remetente/data, estado vazio e indicador de saúde da API.
- Serviço `dashboard` no compose (profile `dashboard`), a ler a API — não escreve na base.

**Critério de aceitação**
- Migração corre de uma base vazia sem erros e pode ser repetida.
- Painel abre com dados seed mesmo que o workflow ainda não tenha corrido.
- Painel não tem botões de escrita nem credenciais de admin.
- README explica como correr o painel.

**Depende de:** contrato da API (§6) e M1. Pode construir contra JSON mockado antes de M4 estar pronto.

### M4 · API + CI (backend) — Afonso (7 h)

**Entregáveis**
- FastAPI com `GET /health`, `POST /api/summaries`, `GET /api/summaries`.
- Modelos Pydantic a validar o contrato (saída estruturada, não `dict` solto).
- Autenticação simples por `X-API-Key` no `POST` (401 sem chave).
- Ligação ao Postgres da aplicação; migrações aplicadas no arranque ou por comando documentado.
- `Dockerfile` + serviço `api` no compose.
- CI no GitHub Actions: `ruff`, `pytest`, `docker compose config`.

**Critério de aceitação**
- OpenAPI disponível em `/docs`.
- `POST` sem chave devolve 401; com chave devolve 201 e o registo aparece no `GET`.
- Testes cobrem o caminho feliz e a ausência de chave.
- CI verde no PR.

**Depende de:** contrato §6 (fechado no dia 1) e esquema M3. O contrato primeiro evita bloquear o Dani.

### M5 · Riscos + modelo de ameaças — Carlos (6 h)

**Entregáveis**
- `docs/risk-register.md`: pelo menos 10 riscos, matriz 5×5, dono, mitigação e data de revisão.
- `docs/threat-model.md`: STRIDE por componente, fronteiras de confiança e diagrama de fluxo de dados.
- Checklist de segredos: IMAP, webhook Discord, chave da API, password do Postgres.
- Nota curta de RGPD: só conta de teste, sem dados pessoais reais, retenção e eliminação.
- Revisão das portas expostas no compose (M1) e do que vai para o repositório público.

**Critério de aceitação**
- Nenhum risco alto sem mitigação e dono atribuído.
- O modelo de ameaças cobre: conteúdo dos emails, credenciais, webhook, base de dados e repositório público.
- Riscos que gerem trabalho ficam ligados a issues (label `risco`).

**Depende de:** arquitetura (§3). Pode começar no dia 1 com o diagrama.

---

## 5. Contrato de interfaces (fechar no dia 1)

Este contrato é o que permite trabalhar em paralelo. Alterações exigem acordo dos donos de M2, M3 e M4.

### `POST /api/summaries`

```http
POST /api/summaries
Content-Type: application/json
X-API-Key: <API_KEY>
```

```json
{
  "message_id": "<id-do-email>",
  "subject": "Fatura de novembro",
  "sender": "billing@exemplo.pt",
  "summary": "- Valor: 12,30 €\n- Vence a 30/11\n- Exige ação: pagar",
  "model": "qwen3:4b",
  "received_at": "2026-11-11T18:00:00Z"
}
```

Resposta `201`:

```json
{ "id": 42 }
```

### `GET /api/summaries?limit=20`

```json
{
  "items": [
    {
      "id": 42,
      "subject": "Fatura de novembro",
      "sender": "billing@exemplo.pt",
      "summary": "…",
      "model": "qwen3:4b",
      "received_at": "2026-11-11T18:00:00Z",
      "created_at": "2026-11-11T18:00:05Z"
    }
  ]
}
```

### Tabela `summaries` (mínimo)

| Coluna | Tipo | Notas |
|---|---|---|
| `id` | `bigserial` | PK |
| `message_id` | `text` | `UNIQUE` quando não nulo (dedupe) |
| `subject` | `text` | |
| `sender` | `text` | |
| `summary` | `text` | |
| `model` | `text` | |
| `received_at` | `timestamptz` | data do email |
| `created_at` | `timestamptz` | `default now()` |

---

## 6. Cronograma e portas de integração

Os dias são relativos ao início; ajustar ao calendário real no kickoff.

| Dia | Trabalho | Porta de integração |
|---|---|---|
| 1 | M1 compose; M3 schema draft; M4 contrato + esqueleto; M5 diagrama; M2 prompt/conta teste | **G1:** `docker compose up` com os 3 serviços healthy |
| 2 | M1 fecha quickstart; M2 primeiro run manual; M4 endpoints; M3 migrações | **G2:** n8n lê email e obtém resumo do Ollama |
| 3 | M2 envia para API e Discord; M4 liga à BD; M3 painel com dados reais | **G3:** email → resumo → Postgres |
| 4 | M2 casos de erro; M3 filtros; M4 CI; M5 revisão de exposição | **G4:** Discord + painel na mesma execução |
| 5 | Correções, README, demo script, tag `v0.1.0` | **Demo + retro** |

**Ritmo** (igual ao roadmap)
- Sessão diária às 21h: 10 min de ponto de situação (feito, bloqueado, próximo); o resto em trabalho de pares.
- Demonstração e retrospetiva de 30 min ao domingo.
- PR revisto em menos de 24 h; nunca commit direto em `main`.
- Um PR por módulo, pequeno, com o critério de aceitação citado na descrição.

---

## 7. Definition of Done da semana

- [ ] `docker compose up -d` sobe Postgres, n8n e Ollama sem passos manuais.
- [ ] Workflow importado lê a conta de teste e resume com Ollama.
- [ ] Resumo chega ao Discord e à API/Postgres.
- [ ] Painel mostra os resumos.
- [ ] README permite a um membro novo reproduzir tudo em menos de 30 min.
- [ ] Nenhum segredo no repositório; `.env.example` documenta todas as variáveis.
- [ ] `docs/risk-register.md` e `docs/threat-model.md` revistos pelo Carlos.
- [ ] CI verde.
- [ ] Tag `v0.1.0` e retro escrita.

---

## 8. Riscos iniciais (semente para o Carlos)

| # | Risco | Prob. | Impacto | Mitigação | Dono |
|---|---|---|---|---|---|
| R1 | Ollama demasiado lento em CPU e a demo arrasta | Alta | Alto | Modelo leve (`qwen3:4b`), prompt curto, 1 email por execução; medir no dia 2 | Lourenço |
| R2 | Credenciais IMAP/webhook acabam no Git | Média | Alto | Só `.env`, `.gitignore` já cobre, checklist no PR, conta de teste | Martim |
| R3 | 36 h sem buffer; integração falha no domingo | Alta | Alto | Portas G1–G4; cortar painel para seed se atrasar >4 h | Todos |
| R4 | n8n/versões mudam e quebram o compose | Média | Médio | Fixar imagens após primeiro sucesso; documentar versões | Martim |
| R5 | Emails reais de pessoas em repositório público | Baixa | Alto | Apenas conta de teste; sem anexos; nota RGPD | Carlos |
| R6 | Donos de M1/M4 colidem no compose | Média | Médio | Contrato §6 e um serviço por PR; M1 fecha a base antes de M4 acrescentar | Martim/Afonso |
| R7 | Workflow reenvia os mesmos emails | Média | Médio | `message_id` único na BD + marcação como lido | Lourenço |

---

## 9. Decisões a confirmar no kickoff

| # | Decisão | Proposta | Alternativa |
|---|---|---|---|
| D1 | Modelo default | `qwen3:4b` (CPU) | `qwen3:8b` se houver GPU |
| D2 | Painel | Streamlit read-only | HTML/JS estático + API |
| D3 | Postgres exposto ao host | Não | Publicar 5432 só em dev |
| D4 | Conta de email | Gmail de teste com app password | Outro IMAP |
| D5 | Escrita na BD | Só pela API | n8n com nó Postgres |
| D6 | Licença | MIT (já no repo) | — |

---

## 10. Perguntas para o grupo

1. Quem cria a conta de teste e o webhook do Discord, e quando? (Martim/Lourenço)
2. O Martim tem GPU disponível? Isso muda D1 e o tempo do resumo.
3. Streamlit chega para o painel ou há preferência por HTML/JS? (Dani)
4. Confirmam a sessão diária às 21h e a demo ao domingo, como no roadmap? (todos)
5. As 36 h são esforço real ou incluem revisão de PR? (todos)
6. Quem faz o merge da release `v0.1.0`? (sugestão: Afonso)
7. O repositório fica público desde já? Confirmar que não há nada sensível no histórico. (Carlos)

---

## 11. Registo de decisões (ADR-lite)

| Data | Decisão | Estado | Nota |
|---|---|---|---|
| 11 nov | n8n + Postgres + Ollama em Docker Compose | aceite (proposta) | base da semana 1 |
| 11 nov | API FastAPI entre n8n e BD | aceite (proposta) | contrato §5 |
| 11 nov | Painel Streamlit read-only | a confirmar | D2 |
| 11 nov | Modelo `qwen3:4b` | a confirmar | D1 |

---

## Anexo · Estrutura do repositório no fim da semana

```
homelab-hub/
├── docker-compose.yml
├── .env.example
├── README.md
├── setup.md
├── db/
│   ├── init/00-create-app-db.sql
│   └── migrations/            # M3
├── api/                       # M4
├── dashboard/                 # M3
├── workflows/
│   ├── README.md
│   └── 01-resumo-emails-discord.json
├── docs/
│   ├── plano-semana-1.md
│   ├── risk-register.md       # M5
│   └── threat-model.md        # M5
└── .github/workflows/ci.yml   # M4
```
