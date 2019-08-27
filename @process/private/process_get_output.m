function out = process_get_output(stream)
  % process_get_output: get the stream (InputStream) content[private]
  
    % use stream readLine method from 
    % this is faster than our 1 by 1 char reader
    reader = java.io.BufferedReader(...
                  java.io.InputStreamReader(stream));
    out = readStream(reader); 
    out = sprintf('%s\n', out{:});
    out = strrep(char(out), sprintf('\n\r'), sprintf('\n'));
  end
  
  % ----------------------------------------------------------------------------
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
