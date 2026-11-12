# Workflows n8n

Ficheiros exportados do n8n. **Nunca** exportar credenciais: o export inclui apenas
referências, mas confirmar antes de fazer commit.

## `01-resumo-emails-discord.json` (M2 · Lourenço)

Fluxo:

```
Schedule (30 min) → IMAP (ler emails) → preparar prompt → Ollama
                                                     ├─→ Discord (webhook)
                                                     └─→ API (guardar resumo)
```

### Como importar

1. Subir a stack: `docker compose up -d` e abrir <http://localhost:5678>.
2. **Workflows → Import from File** e escolher este JSON.
3. No nó **Ler emails**, criar a credencial **IMAP**:
   - Gmail: ativar verificação em dois passos e criar uma **App Password**;
   - servidor `imap.gmail.com`, porta `993`, SSL/TLS.
4. Confirmar que o `.env` tem `DISCORD_WEBHOOK_URL` e `OLLAMA_MODEL` e reiniciar o n8n:
   `docker compose up -d --force-recreate n8n`.
5. Puxar o modelo para o Ollama (uma vez):
   `docker compose exec ollama ollama pull qwen3:4b`.
6. Executar manualmente (**Test workflow**) com um email não lido na caixa.

### Notas

- O nó **Guardar na API** está com *continue on fail*: enquanto o M4 não estiver
  pronto, o fluxo continua e só o Discord é atualizado.
- O `message_id` é enviado para a API; a coluna `message_id` deve ter um índice
  único para impedir duplicados.
- Se o Ollama demorar, reduzir o texto do prompt (limite atual: 6000 caracteres)
  ou usar um modelo mais leve.
