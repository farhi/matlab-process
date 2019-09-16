function out = process_get_output(stream, method)
  % process_get_output: get the stream (InputStream) content[private]
  
  if nargin < 2
    method = 'slow';
  end
  
  if strcmp(method, 'fast')
    out = process_get_output_fast(stream);
  else
    out = process_get_output_slow(stream);
  end
  out = strrep(char(out), sprintf('\n\r'), sprintf('\n'));
end % process_get_output
  
% ----------------------------------------------------------------------------
function out = process_get_output_slow(stream)
  out = '';
  available = 0;
  try
    available = stream.available;
  end

  % return when nothing to read or invalid stream
  if available <= 0, return; end

  % Read the content of the stream.
  %
  % EPIC FAIL 1:
  % The following method would be nice, but fails:
  %   target_buffer = javaArray('java.lang.Byte', available);
  %   stream.read(target_buffer, 0, available);
  %
  % Indeed, as matlab converts any Java array into a Matlab class, 
  % the read method can not be used with additional parameters (signature not found)
  % see http://www.mathworks.com/matlabcentral/answers/66227-syntax-for-call-to-java-library-function-with-byte-reference-parameter
  %
  % EPIC FAIL 2:
  % using readLine from a BufferedReader stalls after a few iterations
  % Reader       = java.io.InputStreamReader(stream);
  % bufferReader = java.io.BufferedReader(Reader);
  % readLine(bufferReader)
  %
  % EPIC FAIL 3: 
  % https://www.mathworks.com/matlabcentral/fileexchange/48164-process-manager
  %  processManager.readStream use while(stream.ready()) stream.readLine();
  % but this may be blocking for interactive processes.

  % we use a for loop to read all bytes, one by one (sadly).
  out = zeros(1, available);
  for index=1:available
    out(index) = read(stream);
  end

end
  
% ----------------------------------------------------------------------------
function out = process_get_output_fast(stream)
  reader = java.io.BufferedReader(...
                java.io.InputStreamReader(stream));
  out = readStream(reader); 
  out = sprintf('%s\n', out{:});
end
  
    %  https://www.mathworks.com/matlabcentral/fileexchange/48164-process-manager
    %  processManager.readStream
    %
    %  Copyright (c) 2014, Brian Lau
    %  All rights reserved.
    %
    %  Redistribution and use in source and binary forms, with or without 
    %  modification, are permitted provided that the following conditions are 
    %  met:
    %
    %      * Redistributions of source code must retain the above copyright 
    %        notice, this list of conditions and the following disclaimer.
    %      * Redistributions in binary form must reproduce the above copyright 
    %        notice, this list of conditions and the following disclaimer in 
    %        the documentation and/or other materials provided with the distribution
    %        
    %  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
    %  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
    %  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
    %  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
    %  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
    %  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
    %  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
    %  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
    %  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
    %  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    %  POSSIBILITY OF SUCH DAMAGE.

function lines = readStream(stream)
  % This is potentially fragile since ready() only checks whether
  % there is an element in the buffer, not a complete line.
  % Therefore, readLine() can block if the process doesn't terminate
  % all output with a carriage return...
  %
  % Alternatives inlcude:
  % 1) Implementing own low level read() and readLine()
  % 2) perhaps java.nio non-blocking methods
  % 3) Custom java class for spawning threads to manage streams
  lines = {};
  while true
    if stream.ready()
       line = stream.readLine();
       if isnumeric(line) && isempty(line)
          % java null is empty double in matlab
          % http://www.mathworks.com/help/matlab/matlab_external/passing-data-to-a-java-method.html
          break;
       end
       c = char(line);
       lines = cat(1,lines,c);
    else
       break;
    end
  end
end
