# coding: utf-8

@dir = "/home/ec2-user/linebot/"

worker_processes 2 # CPUのコア数に揃える
working_directory @dir

timeout 300
#listen 80
listen "#{@dir}tmp/unicorn.sock", backlog: 1024 # UNIXソケットを見るように変更

pid "#{@dir}tmp/pids/unicorn.pid" #pidを保存するファイル

# unicornは標準出力には何も吐かないのでログ出力を忘れずに
stderr_path "#{@dir}log/unicorn.stderr.log"
stdout_path "#{@dir}log/unicorn.stdout.log"

preload_app true
