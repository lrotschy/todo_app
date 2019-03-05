require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
  p session
end

helpers do

  def switch_value(list_idx, todo_idx)
    if session[:lists][list_idx.to_i][:todos][todo_idx.to_i][:completed] == true
      false
    else
      true
    end
  end

  def list_completed?(list)
    total_todos_count(list) >= 1 && remaining_todos_count(list) == 0
  end

  def remaining_todos_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def todo_list_class(todo)
    if todo[:completed]
      "complete"
    else
      nil
    end
  end

  def total_todos_count(list)
    list[:todos].size
  end

  def sort_lists(list, &block)
    finished = {}
    unfinished = {}

    session[:lists].each_with_index do |list, index|
      if list_completed?(list)
        finished[list] = index
      else
        unfinished[list] = index
      end
    end
    unfinished.merge(finished).each(&block)
  end

  def sort_todos(todos, proc, &block)
    finished, unfinished = todos.partition { |todo| todo[:completed] }

    (unfinished + finished).each do |todo|
      yield(todo, todos.index(todo))
    end
  end
end

get "/" do
  redirect "/lists"
end

# GET /lists        -> view all lists
# GET /lists/new    -> new list form
# POST /lists       -> create new list
# GET /lists/1      -> view a single list (with id)

# view list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end



# create a new list
post "/lists" do
  @list_name = params[:list_name].strip
  error = list_name_error(@list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: @list_name, todos: []}
    session[:success] = "New list created"
    redirect "/lists"
  end
end

get "/lists/:index" do
  @list_index = params[:index]
  @todos = session[:lists][@list_index.to_i][:todos]
  @list_name = session[:lists][@list_index.to_i][:name]
  @list = session[:lists][@list_index.to_i]
  erb :list, layout: :layout
end

# edit an existing list
get "/lists/edit/:index" do
  @list_index = params[:index]
  @list_name = session[:lists][@list_index.to_i][:name]
  erb :edit_list, layout: :layout
end

# return error message if list name is invalid; nil if valid

def list_name_error(list_name)
  if session[:lists].any? { |list| list[:name] == list_name }
    "List name must be unique."
  elsif !(1..100).cover? list_name.size
    "List name must be 1 - 100 characters."
  end
end

# submit name change for existing list
post "/lists/:index" do
  @list_index = params[:index]
  new_name = params[:new_list_name].strip
  error = list_name_error(new_name)
  if error
    puts error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][@list_index.to_i][:name ] = new_name
    session[:success] = "List has been updated"
    redirect "/lists/#{@list_index}"
  end
end

# delete a list
post "/lists/:index/destroy" do
  @list_index = params[:index]
  session[:lists].delete_at(@list_index.to_i)
  session[:success] = "List Deleted"
  redirect "/lists"
end


# return error message if todo is invalid; nil if valid
def error_for_todo(todo_name)
  if !(1..100).cover? todo_name.size
    "Todo name must be 1 - 100 characters."
  end
end

# add a todo to a list
post "/lists/:list_index/todos" do
  @list_index = params[:list_index]
  todo_name = params[:todo].strip
  @todos = session[:lists][@list_index.to_i][:todos]

  error = error_for_todo(todo_name)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    session[:lists][@list_index.to_i][:todos] << { name: todo_name, completed: false }
    session[:success] = "Todo item successfully added"
    redirect "/lists/#{@list_index}"
  end
end

# delete a todo item from a list
post "/lists/:list_index/todos/:todo_index/destroy" do
  @list_index = params[:list_index]
  @todo_index = params[:todo_index]
  session[:lists][@list_index.to_i][:todos].delete_at(@todo_index.to_i)
  session[:success] = "Todo has been deleted."
  redirect "/lists/#{@list_index}"
end

# update completed status of todo
post "/lists/:list_index/todos/:todo_index" do
  @list_index = params[:list_index]
  @todo_index = params[:todo_index]
  is_completed = params[:completed] == 'true'
  session[:lists][@list_index.to_i][:todos][@todo_index.to_i][:completed] = is_completed
  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_index}"
end

# mark all todos on a list as completed
post "/lists/:list_index/complete" do
  @list_index = params[:list_index]
  end_index = (session[:lists][@list_index.to_i][:todos].length - 1)

  session[:lists][@list_index.to_i][:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been marked complete."
  redirect "/lists/#{@list_index}"
end
