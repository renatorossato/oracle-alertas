# Oracle Alertas

Este repositório contém a versão **Oracle** dos scripts de alertas e monitoria inspirados no projeto original para SQL Server. O objetivo é fornecer a DBAs e analistas de dados uma solução completa de observabilidade para ambientes Oracle, mantendo a lógica dos alertas originais e acrescentando boas práticas de performance e monitoria adicionais.

## Visão geral

* Todos os scripts e objetos são criados em um esquema dedicado, por padrão `MONITORING`, para isolar artefatos de monitoria.
* A criação de tabelas, sequências, índices e parâmetros de alertas está no script `scripts/2.0_cria_tabelas_alertas.sql`.
* As procedures e funções de monitoria ficam em `scripts/2.1_cria_procedures_e_jobs_oracle.sql`.
* Um conjunto de procedimentos de checklist diário está em `scripts/4.0_checklist_procedures_oracle.sql`.
* O arquivo `scripts/1.0_step_by_step_oracle.sql` apresenta o roteiro de instalação e execução, incluindo pré‑requisitos.

## Pré‑requisitos

1. Oracle Database 12c ou superior.
2. Usuário com privilégios de criação de objetos (por exemplo, `MONITORING`) e acesso às views de dicionário de dados (`SELECT_CATALOG_ROLE`).
3. Pacote `UTL_MAIL` habilitado e configurado (`SMTP_OUT_SERVER` definido). Alternativamente, pode‑se utilizar `UTL_SMTP` (ver documentação em `doc/guia_configuracao.md`).
4. Acesso ao pacote `DBMS_SCHEDULER` para agendar jobs.

## Instalação

Siga o passo a passo descrito no script `scripts/1.0_step_by_step_oracle.sql`. Em resumo:

1. **Crie o esquema e os objetos**: execute `2.0_cria_tabelas_alertas.sql` conectado como o usuário que irá hospedar a solução de monitoria.
2. **Crie as procedures e jobs**: execute `2.1_cria_procedures_e_jobs_oracle.sql` para gerar as procedures de alerta e os jobs do `DBMS_SCHEDULER`.
3. **Opcional: verificação de corrupção**: se desejar monitorar corrupção de dados, ajuste e execute `3.0_checkdb_oracle.sql` (ver notas no script).
4. **Configure e agende a checklist**: execute `4.0_checklist_procedures_oracle.sql` para criar as rotinas de checklist e o job diário que enviará um relatório HTML.
5. **Ajuste parâmetros**: personalize thresholds e configurações na tabela `PARAMETROS_ALERTA` conforme as necessidades do ambiente.

## Estrutura de pastas

```
oracle-alertas/
├── README.md                  # Visão geral e instruções gerais
├── doc/
│   ├── guia_instalacao.md    # Detalhes de instalação e pré‑requisitos
│   ├── guia_configuracao.md  # Como configurar SMTP, privilégios e parâmetros
│   └── guia_troubleshooting.md # Dicas para solução de problemas
├── scripts/
│   ├── 1.0_step_by_step_oracle.sql
│   ├── 2.0_cria_tabelas_alertas.sql
│   ├── 2.1_cria_procedures_e_jobs_oracle.sql
│   ├── 3.0_checkdb_oracle.sql
│   └── 4.0_checklist_procedures_oracle.sql
└── tools/
    └── exemplos_scripts_envio_email/  # Exemplos de scripts externos (opcional)
```

## Créditos

Este projeto é uma adaptação do repositório [Script_SQLServer_Alerts](https://github.com/soupowertuning/Script_SQLServer_Alerts) para Oracle. Todo o código foi reescrito para PL/SQL, seguindo boas práticas de engenharia de dados e monitoria enterprise. Consulte o `CHANGELOG.md` para histórico de versões.
