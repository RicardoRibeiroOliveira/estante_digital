# Estante Digital

## Melhor abordagem para os PDFs

Para o `Estante Digital`, a abordagem agora adotada no codigo e:

- salvar o arquivo PDF diretamente no SQLite como `BLOB`
- manter `pdf_path` apenas como campo legado para compatibilidade com bancos antigos

### Por que isso e melhor?

**Guardar PDF como BLOB no SQLite**

Vantagens:
- tudo fica dentro de um unico arquivo de banco
- o backup do banco leva junto os PDFs
- a importacao do banco restaura a biblioteca completa

Desvantagens:
- o banco cresce muito rapido
- leitura e gravacao tendem a ficar mais pesadas
- backup e restauracao podem ficar mais lentos em arquivos grandes
- manutencao dos arquivos fica menos simples

**Guardar caminho do PDF no banco**

Vantagens:
- banco mais leve
- PDF continua sendo tratado como arquivo
- mais facil abrir no visualizador interno ou em app externo
- melhor separacao entre dados e arquivos

Desvantagens:
- exportar somente o banco nao leva os PDFs junto

### Recomendacao final

Use:

- SQLite para salvar os dados das estantes e livros
- coluna `pdf_data` do tipo `BLOB` para armazenar o PDF
- coluna `pdf_path` apenas para suportar registros antigos, se existirem

## Estrutura recomendada do banco

### Tabela `shelves`

- `id`: identificador da estante
- `name`: nome da estante
- `description`: descricao opcional
- `created_at`: data de criacao
- `updated_at`: data da ultima alteracao

### Tabela `books`

- `id`: identificador do livro
- `shelf_id`: referencia para a estante
- `title`: titulo do livro
- `author`: autor opcional
- `pdf_data`: conteudo binario do PDF
- `pdf_path`: caminho legado opcional para livros antigos
- `file_name`: nome original do arquivo
- `created_at`: data de criacao
- `updated_at`: data da ultima alteracao

## SQL de criacao

```sql
CREATE TABLE shelves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE books (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  shelf_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  author TEXT,
  pdf_data BLOB,
  pdf_path TEXT,
  file_name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (shelf_id) REFERENCES shelves(id) ON DELETE CASCADE
);

CREATE INDEX idx_books_shelf_id ON books (shelf_id);
```

## Estrutura de pastas adotada

```text
lib/
  app.dart
  main.dart
  models/
    book.dart
    shelf.dart
  database/
    app_database.dart
  services/
    database_backup_service.dart
    library_service.dart
    pdf_storage_service.dart
  screens/
    home/
      home_screen.dart
    shelves/
      shelf_form_screen.dart
    books/
      books_screen.dart
      book_form_screen.dart
      pdf_viewer_screen.dart
  widgets/
    empty_state_card.dart
```

## O que cada parte faz

### `models`

Representam os objetos principais da aplicacao:

- `Shelf`
- `Book`

### `database`

Centraliza a conexao com o SQLite, a criacao das tabelas e o caminho do banco.

### `services`

Coloca a regra de negocio fora das telas:

- CRUD de estantes e livros
- selecao e manipulacao dos bytes do PDF
- importacao e exportacao do banco

### `screens`

Contem as telas do app:

- tela inicial com estantes
- formulario de estante
- listagem de livros
- formulario de livro
- visualizacao de PDF

### `widgets`

Componentes pequenos e reutilizaveis.

## Fluxo simples do app

1. O usuario abre a tela inicial e ve suas estantes.
2. Cadastra uma nova estante.
3. Entra na estante.
4. Adiciona um livro em PDF.
5. O app le os bytes do arquivo PDF.
6. Os bytes sao salvos na coluna `pdf_data` da tabela `books`.
7. O usuario toca no livro para abrir o PDF.

## Importacao e exportacao do banco

O projeto ja inclui um servico para:

- exportar o arquivo `.db`
- importar um `.db` existente
- validar se o banco possui as tabelas `shelves` e `books`

### Observacao importante

Agora, ao exportar o banco SQLite, os PDFs cadastrados no formato novo vao junto no mesmo arquivo `.db`.

Se houver livros antigos que ainda usam apenas `pdf_path`, eles continuarao dependendo do arquivo externo ate serem atualizados com um novo PDF.

## Passo a passo simples de implementacao

1. Criar o projeto Flutter.
2. Adicionar as dependencias do SQLite, PDF e selecao de arquivos.
3. Criar os `models`.
4. Criar a classe de banco em `database/app_database.dart`.
5. Criar o servico `library_service.dart` para o CRUD.
6. Criar o servico `pdf_storage_service.dart` para selecionar PDFs e gerar arquivo temporario quando necessario.
7. Criar a tela inicial com a lista de estantes.
8. Criar a tela de cadastro e edicao de estantes.
9. Criar a tela de livros da estante.
10. Criar a tela para selecionar um PDF e cadastrar o livro.
11. Criar a tela de visualizacao do PDF.
12. Criar o servico de importacao e exportacao do banco.
13. Testar criacao, edicao, exclusao, leitura e backup.

## Proximo passo recomendado

Depois de fazer essa base funcionar, os proximos aprimoramentos mais uteis sao:

- busca de livros por titulo
- capa personalizada para cada livro
- filtro por autor
- organizacao por categorias ou tags
