module CounterCacheResets
  module_function

  def posts
    execute sql_for(Post, :post_likes)
    execute sql_for(Post, :comments)
    execute sql_for(Post, :comments,
      counter_cache_column: 'top_level_comments_count',
      where: 'parent_id IS NULL')
  end

  def media_user_counts
    execute sql_for(Anime, :library_entries, counter_cache_column: 'user_count')
    execute sql_for(Manga, :library_entries, counter_cache_column: 'user_count')
  end

  def media_rating_frequencies
    execute rating_frequencies_for(Anime)
    execute rating_frequencies_for(Manga)
    execute rating_frequencies_for(Drama)
  end

  def favorite_counts
    execute sql_for(Anime, :favorites, counter_cache_column: 'favorites_count')
    execute sql_for(Manga, :favorites, counter_cache_column: 'favorites_count')
  end

  def users
    execute sql_for(User, :library_entries,
      counter_cache_column: 'ratings_count',
      where: 'rating IS NOT NULL')
    execute sql_for(User, :post_likes,
      counter_cache_column: 'likes_given_count')
    execute sql_for(User, :favorites)
  end

  def groups
    execute sql_for(Group, :members)
    execute sql_for(Group, :members,
      counter_cache_column: 'leaders_count',
      where: 'rank != 0')
  end

  def reviews
    execute sql_for(User, :reviews)
  end

  def clean!
    tables = ActiveRecord::Base.connection.tables.grep(/_count\z/)
    execute tables.map { |t| "DROP TABLE #{t}" }
  end

  def rating_frequencies_for(model)
    model_name = model.name.underscore
    foreign_key = "#{model_name}_id"
    temp_table = "#{model_name}_rating_frequencies"
    [
      "DROP TABLE IF EXISTS #{temp_table}",
      <<-SQL.squish,
        CREATE TEMP TABLE #{temp_table} AS
        SELECT le.#{foreign_key}, rating, count(*)
        FROM library_entries le
        WHERE le.#{foreign_key} IS NOT NULL
          AND le.rating IS NOT NULL
        GROUP BY le.#{foreign_key}, rating
      SQL
      <<-SQL.squish,
        CREATE INDEX ON #{temp_table} (#{foreign_key}, rating)
      SQL
      "VACUUM #{temp_table}",
      <<-SQL.squish,
        UPDATE #{model.table_name}
        SET rating_frequencies = ARRAY[#{
          LibraryEntry::VALID_RATINGS.map { |rating|
            "'#{rating}', COALESCE((
              SELECT count
              FROM #{temp_table}
              WHERE #{temp_table}.#{foreign_key} = #{model.table_name}.id
                AND #{temp_table}.rating = #{rating}
            ), 0)"
          }.join(', ')
        }]::text[]::hstore
      SQL
      "DROP TABLE #{temp_table}"
    ]
  end

  def sql_for(model, association_name, counter_cache_column: nil, where: nil)
    association = model.reflections[association_name.to_s]
    inverse = association.inverse_of
    is_polymorphic = inverse.polymorphic?
    counter_cache_column ||= inverse.counter_cache_column
    temp_table = "#{model}_#{association.name}_count"
    poly_where = "#{inverse.foreign_type} = '#{model.name}'" if is_polymorphic
    where = [where, poly_where].compact.join(' AND ')
    [
      "DROP TABLE IF EXISTS #{temp_table}",
      <<-SQL.squish,
        CREATE TEMP TABLE #{temp_table} AS
        SELECT #{is_polymorphic && "#{inverse.foreign_type}, "}
               #{association.foreign_key}, count(*) AS count
        FROM #{association.table_name}
        #{where.present? ? "WHERE #{where}" : ''}
        GROUP BY #{is_polymorphic && "#{inverse.foreign_type}, "}
                 #{association.foreign_key}
      SQL
      <<-SQL.squish,
        CREATE INDEX ON #{temp_table} (
          #{is_polymorphic && "#{inverse.foreign_type}, "}
          #{association.foreign_key}
        )
      SQL
      "VACUUM #{temp_table}",
      <<-SQL.squish,
        UPDATE #{model.table_name}
        SET #{counter_cache_column} = COALESCE((
          SELECT count
          FROM #{temp_table}
          WHERE #{association.foreign_key} = #{model.table_name}.id
            #{is_polymorphic && "AND #{poly_where}"}
        ), 0)
      SQL
      "DROP TABLE #{temp_table}"
    ]
  end

  def execute(sql, title = 'Executing SQL')
    if sql.respond_to?(:each)
      say_with_time(title) do
        sql.each do |query|
          say(query.to_s, true)
          ActiveRecord::Base.connection.execute(query)
        end
      end
    else
      say_with_time(sql) do
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end

  # Method pulled from ActiveRecord::Migration (under MIT, not Apache)
  def say(message, subitem = false)
    puts "#{subitem ? '   ->' : '--'} #{message}"
  end

  # Method pulled from ActiveRecord::Migration (under MIT, not Apache)
  def say_with_time(message)
    say(message)
    result = nil
    time = Benchmark.measure { result = yield }
    say format('%.4fs', time.real), :subitem
    say("#{result} rows", :subitem) if result.is_a?(Integer)
    result
  end

  def progress_bar(title, count)
    ProgressBar.create(
      title: title,
      total: count,
      output: STDERR,
      format: '%a (%p%%) |%B| %E %t'
    )
  end
end
