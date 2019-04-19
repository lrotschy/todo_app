
class SessionPersistence

  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id.to_i }
  end

  def all_lists
    @session[:lists]
  end

  def delete_list(id)
    @session[:lists].reject! { |list| list[:id] == id.to_i }
  end

  def create_list(name)
    @session[:lists] << { name: name, id: next_element_id(@session[:lists]), todos: [] }
  end

  def rename_list(id, name)
    list = find_list(id)
    list[:name] = name
  end

  def next_element_id(elements)
      max = elements.map { |elem| elem[:id] }.max || 0
      max + 1
  end

  def add_todo(list_id, name, completed=false)
    list = find_list(list_id)
    todo_id = next_element_id(list[:todos])
    list[:todos] << { id: todo_id, name: name, completed: completed }
  end

  def delete_todo_item(list_id, todo_id)
    list = find_list(list_id)

    list[:todos] = list[:todos].reject! do |todo|
      todo[:id] == todo_id
    end
  end

  def update_completed_status(list_id, todo_id, status)
    list = find_list(list_id)
    todo = list[:todos].find { |todo| todo[:id] == todo_id.to_i }
    todo[:completed] = status
  end

  def mark_all_completed(list_id)
    list = find_list(list_id)
    list[:todos].each do |todo|
      todo[:completed] = true
    end
  end

end
