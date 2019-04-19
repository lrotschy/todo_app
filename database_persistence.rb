require 'pg'

class DatabasePersistence

  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end 

  def query(statement, *params)
    @logger.info"#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM lists WHERE id = $1"
    result = query(sql, id)
    tuple = result.first
    { id: tuple["id"], name: tuple["name"], todos: list_todos(tuple["id"]) }
  end

  def all_lists
    sql = "SELECT * FROM lists"
    result = query(sql)
    result.map do |tuple|
      { id: tuple["id"].to_i, name: tuple["name"], todos: list_todos(tuple["id"]) }
    end
  end

  def create_list(name)
    sql = "INSERT INTO lists (name) VALUES ($1);"
    query(sql, name)
  end

  def delete_list(id)
    sql_1 = "DELETE FROM todos WHERE list_id = $1;"
    query(sql_1, id)
    sql_2 = "DELETE FROM lists WHERE id = $1;"
    query(sql_2, id)
  end

  def rename_list(id, name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, name, id)
  end

  def add_todo(list_id, name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2);"
    query(sql, name, list_id)
  end

  def delete_todo_item(list_id, todo_id)
    sql = "DELETE FROM todos WHERE id = $1 AND list_id = $2;"
    query(sql, todo_id, list_id)
  end

  def update_completed_status(list_id, todo_id, status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 and list_id = $3;"
    query(sql, status, todo_id, list_id)
  end

  def mark_all_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1;"
    query(sql, list_id)
  end

  private

  def list_todos(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    result = query(sql, list_id)
    todos = result.map do |tuple|
      { id: tuple["id"].to_i, name: tuple["name"], completed: tuple["completed"] == "t" }
    end
  end

end
