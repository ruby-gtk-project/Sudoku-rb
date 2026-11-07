# frozen_string_literal: true

# Exercises lib/sudoku/log_utils.rb (ported from upstream src/log_utils.py).
#
# Upstream ships no dedicated test module for log_utils.py, so there is no
# 1:1 upstream test to port here; this closes the zero-coverage gap the
# component-parity report named for this unit.

RSpec.describe Sudoku::LogUtils do
  after do
    Sudoku::LogUtils.instance_variable_set(:@buffer, nil)
    Sudoku::LogUtils.instance_variable_set(:@logger, nil)
  end

  it "has no buffer and empty logs before setup_logging runs" do
    expect(Sudoku::LogUtils.buffer).to be_nil
    expect(Sudoku::LogUtils.logs).to eq("")
  end

  it "setup_logging installs a buffer-backed logger and returns it" do
    sink = Sudoku::LogUtils.setup_logging
    expect(sink).to be_a(Sudoku::LogBuffer)
    expect(Sudoku::LogUtils.buffer).to equal(sink)
  end

  it "records logged messages into the buffer, reachable through LogUtils.logs" do
    Sudoku::LogUtils.setup_logging
    Sudoku::LogUtils.logger.info("sudoku test message")
    expect(Sudoku::LogUtils.logs).to include("sudoku test message")
  end

  it "keeps accumulating across multiple log calls" do
    Sudoku::LogUtils.setup_logging
    Sudoku::LogUtils.logger.debug("first line")
    Sudoku::LogUtils.logger.warn("second line")
    expect(Sudoku::LogUtils.logs).to include("first line")
    expect(Sudoku::LogUtils.logs).to include("second line")
  end
end

RSpec.describe Sudoku::LogBuffer do
  let(:buffer) { Sudoku::LogBuffer.new }

  it "starts with empty logs" do
    expect(buffer.logs).to eq("")
  end

  it "write appends to the in-memory log and returns the byte count" do
    written = buffer.write("hello")
    expect(written).to eq("hello".bytesize)
    expect(buffer.logs).to eq("hello")
  end

  it "accumulates across multiple writes, like upstream's io.StringIO sink" do
    buffer.write("one")
    buffer.write("two")
    expect(buffer.logs).to eq("onetwo")
  end

  it "close is a no-op, matching upstream leaving the stream open for get_logs" do
    expect(buffer.close).to be_nil
    expect { buffer.write("still works") }.not_to raise_error
  end
end
