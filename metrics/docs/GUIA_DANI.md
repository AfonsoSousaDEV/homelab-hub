# Guia do Dani

A tua entrega é tornar o funcionamento do Homelab observável: saber quantas execuções
houve, quanto demoraram, quantos emails foram resumidos e onde ocorreram falhas.

## O que existe nesta primeira versão

- `db/migrations/001_execution_metrics.sql`: tabela, regras de consistência, índices e vista.
- `db/migrations/002_protect_completed_runs.sql`: impede alterações a execuções terminadas.
- `db/queries/`: consultas para o resumo das últimas 24 horas, evolução por hora e execuções demoradas.
- `grafana/`: ligação PostgreSQL e painel carregados automaticamente.
- `db/seed/demo.sql`: exemplos artificiais, carregados apenas quando pedires.
- `tests/metrics.sql`: testes reais em PostgreSQL; os registos dos testes são revertidos.
- `tests/check_stale_panel.py`: confirma que uma execução antiga continua visível no indicador.
- `docs/INTEGRATION.md`: contrato que deves combinar com o Afonso e o Lourenço.
- `docs/VALIDATION.md`: resultados e limites da validação local desta versão.

Começa pelos comandos do README. A base de dados arranca vazia; carregar a demo é
opcional. O workflow real, o serviço de resumo e a VPN pertencem às outras tarefas.

## Como ler o modelo

Uma linha representa uma tentativa completa do workflow. O par `workflow_key` e
`execution_key` identifica-a sem duplicados. `started_at` marca o início; `finished_at`
o fim. `duration_ms` é calculado na vista a partir desses tempos.

Os estados são `running` (em curso), `succeeded` (terminou bem) e `failed` (terminou
com erro). Uma execução sem emails também pode terminar bem. Se o workflow parar
abruptamente, pode ficar em curso; o painel destaca esses casos após 15 minutos.
Esse indicador mostra a situação atual em todo o histórico, independentemente do
intervalo escolhido no painel. Uma execução antiga não desaparece da contagem quando
escolhes as últimas 24 horas ou os últimos 5 minutos.

As execuções terminadas ficam protegidas na própria base de dados: não se pode mudar
um sucesso para uma falha, reabrir uma execução ou reescrever as suas métricas.
Uma nova tentativa deve ter um novo identificador de execução.

A taxa de sucesso divide os sucessos pelas execuções **já terminadas**. O percentil
95 da duração é um valor abaixo do qual ficam cerca de 95% das durações observadas;
ajuda a ver lentidão que a média pode esconder. Com poucas execuções, interpreta-o
com cuidado. Estas métricas não avaliam a qualidade dos resumos.

## Próximos passos contigo e com o grupo

1. Confirmar os campos e os códigos de erro com o Afonso e o Lourenço.
2. Combinar com o Martim a base de dados e a rede do ambiente comum.
3. Ligar uma execução real de uma conta de teste e verificar a linha e o painel.
4. Testar uma falha controlada do Ollama e confirmar o código e a duração.
5. Decidir o prazo de retenção, experimentar backup/restauro numa base separada e
   preparar uma demonstração curta das métricas.

Não alteres uma migração já aplicada em equipa: cria a seguinte, por exemplo `002_...`.
Os scripts de arranque só correm quando o volume PostgreSQL está vazio. Alterar o SQL
ou as passwords no `.env` não atualiza automaticamente uma base já inicializada.

O painel é gerido pelo ficheiro JSON: para experimentar na interface, guarda uma cópia
com outro nome. Combina as alterações finais no ficheiro antes de as partilhar.
