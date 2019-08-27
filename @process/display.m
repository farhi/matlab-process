function d = display(s_in, name)
  % DISPLAY display Process object (from command line)

  if nargin == 2 && ~isempty(name)
    iname = name;
  elseif ~isempty(inputname(1))
    iname = inputname(1);
  else
    iname = 'ans';
  end

  d = [ sprintf('%s = ',iname) ];

  if isdeployed || ~usejava('jvm') || ~usejava('desktop'), id=class(s_in);
  else           id=[ '<a href="matlab:doc process">process</a> (<a href="matlab:methods process">methods</a>,<a href="matlab:help process">doc</a>,<a href="matlab:read(' iname ')">stdout</a>,<a href="matlab:exit(' iname ')">exit</a>,<a href="matlab:disp(' iname ');">more...</a>)' ];
  end
  
  if length(s_in) == 0
      d = [ d sprintf(' %s: empty\n',id) ];
  elseif length(s_in) == 1 && ~isvalid(s_in)
      d = [ d sprintf(' %s: invalid\n',id) ];
  elseif length(s_in) >= 1
    % print header lines
    if length(s_in) == 1
      d = [ d sprintf(' %s:\n\n', id) ];
    else
      d = [ d id sprintf(' array [%s]',num2str(size(s_in))) sprintf('\n') ];
    end
    if length(s_in) > 1
      d = [ d sprintf('Index ') ];
    end
    d = [ d sprintf('     [ID] [Command]                     [State] [output]\n') ];

    % now build the output string using char method
    d = [ d char(s_in) ];
  end

  if nargout == 0
    fprintf(1,d);
  end

end


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

