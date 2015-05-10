require "../bson/bson"
require "./lib_mongo"
require "./host"

class Mongo::Cursor
  def initialize(@handle: LibMongoC::Cursor)
    @data = Pointer(LibBSON::BSON).malloc(1)
    @closed = false
  end

  include Enumerable(BSON)

  def finalize
    close
  end

  def close
    return if @closed
    @closed = true
    LibMongoC.cursor_destroy(self)
  end

  private def check_closed
    raise "cursor is closed" if @closed
  end

  # This method shall create a copy of a `Cursor`. The cloned cursor will be
  # reset to the beginning of the query, and therefore the query will be
  # re-executed on the MongoDB server when `next` is called.
  def clone
    check_closed
    handle = LibMongoC.cursor_clone(self)
    Cursor.new handle
  end

  # This method shall indicate if there is more data to be read from the
  # cursor.
  def more
    check_closed
    LibMongoC.cursor_more(self)
  end

  # This method shall iterate the underlying cursor, setting `BSON` to the
  # next document.
  # It returns `nil` if the cursor was exhausted.
  def next
    check_closed
    if LibMongoC.cursor_next(self, @data)
      check_error
      @current = BSON.copy_from @data.value
    end
  end

  # This method iterates the underlying cursor passing the resulted documents
  # to the specified block.
  def each
    check_closed
    while v = self.next
      yield v
    end
  end

  private def check_error
    if LibMongoC.cursor_error(self, out error)
      raise BSON::BSONError.new(pointerof(error))
    end
  end

  # Fetches the MongoDB host that the cursor is communicating with in the host
  # out parameter.
  def host
    check_closed
    LibMongoC.cursor_get_host(self, out hosts)
    Host.hosts(pointerof(hosts)).first
  end

  # Checks to see if a cursor is in a state that allows for more documents to
  # be queried. This is primarily useful with tailable cursors.
  def alive?
    return false if @closed
    LibMongoC.cursor_is_alive(self)
  end

  # Fetches the cursors current document.
  def current
    check_closed
    @current
  end

  # 
  def batch_size
    check_closed
    LibMongoC.cursor_get_batch_size(self)
  end

  def batch_size=(size)
    check_closed
    LibMongoC.cursor_set_batch_size(self, size.to_u32)
  end

  def hint
    check_closed
    LibMongoC.cursor_get_hint(self)
  end

  def id
    check_closed
    LibMongoC.cursor_get_id(self)
  end

  def to_unsafe
    check_closed
    @handle
  end
end
