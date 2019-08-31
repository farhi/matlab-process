function d=char(pid)
  % CHAR convert a process object into char string
  d = [];
  for index=1:length(pid)
    if ~isvalid(pid(index)), continue; end
    if length(pid) > 1, d = [ d sprintf('%5i ', index) ]; end
    this = get_index(pid, index);
    refresh_Process(this);
    if isjava(this.Runtime)
      c = char(this.Runtime);
    else c = num2str(this.Runtime);
    end
    if numel(c)>9, c=c((end-8):end); end
    d = [ d sprintf('%8s ', c) ];
    if iscellstr(this.command), c=sprintf('%s ', this.command{:});
    else c = char(this.command); end
    if numel(c)>30, c=[ c(1:27) '...' ]; end
    d = [ d sprintf('%30s ', num2str(c)) ];                   % cmd;

    if this.isActive
      d = [ d 'Run    ' ];
    else
      d = [ d 'Stop   ' ];
    end
    if ~isempty(this.stderr), d=[ d '[ERR]' ]; end
    d = [ d sprintf('%s\n', Process_display_out(this.stdout)) ];
  end
end % end

% ------------------------------------------------------------------------------
function out = Process_display_out(str)
  if isempty(str), out=''; return; end
  lines = strread(str,'%s','delimiter','\n\r');
  if numel(lines) < 5
    out = sprintf('%s ', lines{:});
  else
    out = sprintf('%s ', lines{(end-4):end});
  end
  if numel(out) > 40, out = [ '...' out((end-35):end) ]; end
  out = deblank(out);
end

function obj = get_index(pid, index)
  S.type='()'; S.subs = {index};
  obj = subsref(pid, S);
end
