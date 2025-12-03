# Guia de Troubleshooting – Oracle Alertas

Esta seção reúne dicas para diagnosticar e resolver problemas comuns que podem ocorrer durante a execução das rotinas de monitoria.

## Problemas de envio de e‑mail

1. **Mensagem “ORA‑29279: SMTP transient error”**: verifique se o servidor SMTP está acessível a partir do servidor Oracle e se a porta configurada (25 ou 587) está aberta. Teste a conectividade via telnet.
2. **Erro de privilégio ao usar `UTL_MAIL` ou `UTL_SMTP`**: certifique‑se de que o usuário de monitoria possui `GRANT EXECUTE ON UTL_MAIL/UTL_SMTP`. Se a instância estiver configurada com ACL (Access Control List), crie uma ACL via `DBMS_NETWORK_ACL_ADMIN` e associe o host SMTP ao usuário.
3. **E‑mails em branco**: revise o template HTML e as consultas de construção do corpo do e‑mail. Um erro comum é não inicializar o `CLOB` antes de concatenar partes.

## Jobs não executam ou ficam DISABLED

* Verifique a coluna `STATE` na view `USER_SCHEDULER_JOBS`. Se estiver `FAILED` ou `BROKEN`, veja detalhes em `USER_SCHEDULER_JOB_RUN_DETAILS`.
* Aplique `DBMS_SCHEDULER.RUN_JOB` manualmente para testar:

```sql
BEGIN
  DBMS_SCHEDULER.RUN_JOB('MONITORING.PR_ALERTA_ESPACO_TBS_JOB');
END;
/
```

* Certifique‑se de que o serviço do Scheduler está ativado (`SELECT * FROM V$INSTANCE WHERE SCHEDULER_DISABLED = 'TRUE'`).

## Alertas não estão disparando

* Confirme os valores de limiar na tabela `PARAMETROS_ALERTA`; valores muito altos podem impedir o disparo.
* Execute manualmente a procedure correspondente com valores de teste e registre a saída.
* Verifique se a tabela de logs (`LOG_*`) está sendo preenchida. Caso contrário, a consulta pode não estar retornando linhas; revise a lógica de cálculo (especialmente conversões de unidades e cast de datas).

## Erros de sintaxe ou privilégios ao executar scripts

* Certifique‑se de estar conectado como o usuário correto (por exemplo, `monitoring`) durante a criação de objetos. Muitos scripts utilizam a sintaxe `CREATE OR REPLACE PACKAGE`, que requer privilégio `CREATE ANY PROCEDURE` se executado fora do próprio schema.
* Ajuste o `NLS_DATE_FORMAT` e o `NLS_NUMERIC_CHARACTERS` se encontrar erros de conversão de data ou número. Inclua `ALTER SESSION SET NLS_LANGUAGE` no início dos scripts se necessário.

## Alto consumo de CPU/IO causado pela monitoria

* Programe as execuções durante períodos de menor carga.
* Revise as consultas de monitoria e adicione índices de apoio nas tabelas de log (`LOG_WAITS`, `LOG_IO_PENDING`, etc.).
* Consulte `V$ACTIVE_SESSION_HISTORY` para identificar se as próprias procedures estão gerando waits significativos e otimize‑as.

## Atualização de versão

Ao atualizar os scripts para uma nova versão, siga estes passos:

1. Faça backup de todas as tabelas de log e parâmetros, caso precise retornar à versão anterior.
2. Execute os scripts de migração na ordem recomendada (descrita no `CHANGELOG.md`).
3. Teste as novas procedures em ambiente de homologação antes de levar para produção.

Caso encontre problemas não documentados, registre uma *issue* no repositório para que a comunidade possa ajudar.
