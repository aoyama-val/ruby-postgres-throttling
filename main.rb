require 'pg'

def main
  init
  request(user_id: ARGV[0] || 'a')
end

def init
  host = 'localhost'
  port = 5432
  db = 'postgres'
  user = 'postgres'
  password = 'postgres'
  @conn = PG::Connection.new(host: host, port: port, dbname: db, user: user, password: password)
end

def request(user_id:)
  puts "user_id = #{user_id}"
  inserted = false
  begin
    @conn.exec('INSERT INTO locks (user_id, accepted_at) VALUES ($1, now())', [user_id])
    inserted = true
  rescue => e
    if e.is_a? PG::UniqueViolation
      puts 'unique制約に引っかかりましたが、問題ありません'
    else
      raise
    end
  end
  @conn.exec('BEGIN')
  @conn.exec('SELECT *, EXTRACT(EPOCH FROM now() - accepted_at) AS elapsed FROM locks WHERE user_id = $1 FOR UPDATE', [user_id]).each do |row|
    puts "#{row['elapsed']}秒経過"
    if !inserted && row['elapsed'].to_i < 10 # 秒
      puts 'まだダメです'
      @conn.exec('COMMIT')
      return
    end
  end
  @conn.exec('UPDATE locks SET accepted_at = now() WHERE user_id = $1', [user_id])
  @conn.exec('COMMIT')
  puts 'リクエストOKです'
end

main
