require 'digest'

class Store::Mediafire

  def initialize(credential)
    @agent = RestClient
    #@agent.log = Logger.new $stdout
    @host = 'https://www.mediafire.com'
    @api_version = '1.4'
    @logged_in = false
    @credential = credential
  end

  def request(path, params, headers = {}, &block)
    path = api_path(path)
    params.merge! response_format: 'json'
    if @logged_in
      params.merge! session_token: @session_token
      query = URI.encode_www_form params
      url = "#{path}?#{query}"
      signature = Digest::MD5.hexdigest("#{@secret_key % 256}#{@time}#{url}")
      params.merge! signature: signature
    end
    headers.merge! params: params, accept: 'json'
    begin
      body = block.call "#{@host}#{path}", headers
    rescue => e
      body = e.response
    end
    res = JSON.parse(body)['response']
    if res['new_key'] == 'yes'
      @secret_key = (@secret_key * 16807) % 2147483647
    end
    #puts JSON.pretty_generate res
    res
  end

  def api_path(path) "/api/#{@api_version}#{path}" end

  def req_get(path, params = {})
    request path, params do |url, headers|
      @agent.get url, headers
    end
  end

  def req_post(path, payload, params, headers = {})
    request path, params, headers do |url, headers|
      @agent.post url, payload, headers
    end
  end

  def login
    email    = @credential['email']
    password = @credential['password']
    app_id   = @credential['app_id']
    api_key  = @credential['api_key']
    signature = Digest::SHA1.hexdigest "#{email}#{password}#{app_id}#{api_key}"
    res = req_get '/user/get_session_token.php',
      email:          email,
      password:       password,
      application_id: app_id,
      signature:      signature,
      token_version: 2
    @session_token = res['session_token']
    @secret_key    = res['secret_key'].to_i
    @time          = res['time']
    @logged_in     = res['result'] == 'Success'
  end

  def info
    req_get '/user/get_info.php'
  end

  def request_all
    items = []
    chunk = 1
    done = false
    while !done
      done   = yield chunk, items
      chunk += 1
    end
    items
  end

  def generic_ls(path, type)
    request_all do |chunk, items|
      res = req_get '/folder/get_content.php',
        content_type: type,
        folder_path:  path,
        chunk:        chunk,
        chunk_size:   1000
      content = res['folder_content']
      items.concat content[type]
      content['more_chunks'] == 'no'
    end
  end

  def ls(path)
    path        = abs_path path
    folders     = generic_ls path, 'folders'
    files       = generic_ls path, 'files'
    folders.each do |folder|
      pretty_ls '', folder['created_utc'], folder['name'].bold.blue
    end
    files.each do |file|
      size = Filesize.from("#{file['size']} B").pretty
      pretty_ls size, file['created_utc'], file['filename']
    end
    [folders, files]
  end

  def pretty_ls(size, created, name)
    puts "  #{size.rjust(11).magenta} #{created.cyan} #{name}"
  end

  def mkdir(path)
    req_get '/folder/create.php',
      parent_path: abs_path(path.dirname),
      foldername:  abs_path(path).basename
  end

  def rmdir(path)
    req_get '/folder/delete.php',
      folder_path: abs_path(path)
  end

  def rmdir_f(path)
    req_get '/folder/purge.php',
      folder_path: abs_path(path)
  end

  def abs_path(path)
    path = path.relative_path_from Pathname.new(?/)
    path == Pathname.new(?.) ? Pathname.new('') : Pathname.new(?/) + path
  end

  def put(path, remote)
    filename = path.basename
    filesize = path.size
    filehash = Digest::SHA256.file(path).hexdigest
    dirname  = abs_path remote.dirname
    open path do |file|
      loop do
        res = req_get '/upload/check.php',
          path:      dirname,
          filename:  filename,
          size:      filesize,
          hash:      filehash,
          resumable: 'yes'
        copyable, uploaded, unit_size, unit_id = next_unit res
        if copyable
          req_get '/upload/instant.php',
            path:      dirname,
            filename:  filename,
            size:      filesize,
            hash:      filehash,
            resumable: 'yes'
          break
        end
        break if uploaded
        offset = unit_id * unit_size
        size = [unit_size, filesize - offset].min
        file.seek offset
        payload = file.read size
        unit_hash = Digest::SHA256.hexdigest payload
        res = req_post '/upload/resumable.php', payload, {
          'path':         dirname
        }, {
          'x-filename':   filename,
          'x-filesize':   filesize,
          'x-filehash':   filehash,
          'x-unit-hash':  unit_hash,
          'x-unit-id':    unit_id,
          'x-unit-size':  size,
          'content-type': 'application/octet-stream'
        }
      end
    end
    puts '  upload success !'
  end

  def next_unit(res)
    copyable  = (res['hash_exists'] == 'yes' &&
                 res['in_folder']   == 'no'  &&
                 res['file_exists'] == 'no')
    resumable = res['resumable_upload']
    uploaded  = (resumable['all_units_ready'] == 'yes' &&
                 resumable['result'].to_i     == 0)
    units_len = resumable['number_of_units'].to_i
    unit_size = resumable['unit_size'].to_i
    unit_id   = resumable['bitmap']['words'].flat_map do |word|
      word = word.to_i
      0.upto(15).map do |unit|
        word, bit = word.divmod 2
        bit == 1
      end
    end[0...units_len].index(false)
    [copyable, uploaded, unit_size, unit_id]
  end

  def get(path, local)
    res = req_get '/file/get_links.php',
      file_path: abs_path(path),
      link_type: 'direct_download'
    link = res['links'][0]['direct_download']
    open link do |recv|
      open local, 'w+' do |send|
        while (buf = recv.read 8192)
          send.write buf
        end
      end
    end
  end

  def rm(path)
    req_get '/file/delete.php',
      file_path: abs_path(path)
  end

  def rm_f(path)
    req_get '/file/purge.php',
      file_path: abs_path(path)
  end

  def trash_rm(path)
    filename = path.basename.to_s
    request_all do |chunk, items|
      res = req_get '/device/get_trash.php',
        chunk:        chunk,
        content_type: 'files',
        data_only:    'no'
      items.concat res['files']
      items.size >= res['file_count'].to_i
    end.select do |file|
      name = file['filename']
      (name.start_with?(filename) &&
       !!(name[filename.size..-1] =~ /^(?:\(\d+\))?$/))
    end.each do |file|
      quickkey = file['quickkey']
      req_get '/file/purge.php',
        quick_key: quickkey
    end
  end

  def trash_rm_all
    req_get '/device/empty_trash.php'
  end
end
