# Guia de Instalação – Oracle Alertas

Este guia descreve os passos necessários para instalar e habilitar os scripts de alertas em um ambiente Oracle. Certifique‑se de seguir cada etapa com atenção para garantir o funcionamento correto da solução.

## 1. Criar o usuário e esquema de monitoria

É recomendado criar um usuário dedicado para hospedar todos os objetos de monitoria. Por exemplo:

```sql
-- Conecte‑se como DBA e crie o usuário
CREATE USER monitoring IDENTIFIED BY senha_forte
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON users;

-- Conceda privilégios necessários
GRANT CONNECT, RESOURCE TO monitoring;
GRANT SELECT_CATALOG_ROLE TO monitoring;
GRANT EXECUTE ON UTL_MAIL TO monitoring;
GRANT EXECUTE ON UTL_SMTP TO monitoring;
-- Caso precise ler os alert logs via OS:
-- GRANT CREATE EXTERNAL JOB TO monitoring;
```

O nome do usuário pode ser alterado conforme preferência. Ajuste também tablespaces e quotas de acordo com a política da sua empresa.

## 2. Configurar o envio de e‑mail

A solução utiliza o pacote `UTL_MAIL` para enviar alertas. Para ativá‑lo, siga os passos abaixo (como DBA):

```sql
-- Habilitar o pacote UTL_MAIL (executar como SYS)
@?/rdbms/admin/utlmail.sql
@?/rdbms/admin/prvtmail.plb

-- Definir servidor SMTP
ALTER SYSTEM SET smtp_out_server = 'smtp.seu-servidor.com:25' SCOPE = BOTH;

-- Opcionalmente definir remetente padrão
ALTER SYSTEM SET email_server_ssl = FALSE SCOPE = BOTH;
```

Certifique‑se de que o servidor SMTP está acessível a partir do servidor Oracle e que a porta está liberada. Caso utilize TLS ou autenticação, adapte a configuração ou utilize o pacote `UTL_SMTP` com código personalizado (veja exemplos em `tools/exemplos_scripts_envio_email`).

## 3. Executar os scripts na ordem correta

1. `scripts/2.0_cria_tabelas_alertas.sql` – cria todas as tabelas, sequências, índices e carrega a tabela de parâmetros com os alertas padrão.
2. `scripts/2.1_cria_procedures_e_jobs_oracle.sql` – cria o pacote de utilidades, procedures de alertas e agenda os jobs via `DBMS_SCHEDULER`.
3. Opcional: `scripts/3.0_checkdb_oracle.sql` – adiciona rotina de verificação de corrupção (DBVERIFY) e agenda job, se aplicável.
4. `scripts/4.0_checklist_procedures_oracle.sql` – cria procedures para checklist diário e agenda job para envio de relatório.

Execute cada script conectado como o usuário de monitoria (por exemplo, `monitoring`).

## 4. Ajustar parâmetros de alerta

Todos os thresholds e configurações de e‑mail são armazenados na tabela `PARAMETROS_ALERTA`. Após executar os scripts, atualize os valores conforme as necessidades do ambiente:

```sql
-- Exemplo: ajustar limite de utilização de tablespace para 85%
UPDATE parametros_alerta
   SET valor = 85
 WHERE nome_parametro = 'LIMITE_TABLESPACE_PCT';

COMMIT;
```

A descrição e a finalidade de cada parâmetro estão documentadas nos comentários da tabela e no script de criação. Utilize valores adequados para sua realidade (tempo de resposta, percentual de uso, número de eventos etc.).

## 5. Testar alertas

É recomendável validar cada alerta antes de colocar em produção. Você pode forçar situações controladas, por exemplo:

1. Preencher uma tablespace de teste até exceder o limite configurado para disparar `pr_alerta_espaco_tbs`.
2. Criar um bloqueio intencional (sessão aguardando outra) para testar `pr_alerta_processo_bloqueado`.
3. Gerar um evento de deadlock via transações conflitantes para validar `pr_alerta_deadlock`.

Verifique se o e‑mail enviado contém o corpo em HTML e os detalhes esperados. Ajuste templates e parâmetros conforme necessário.