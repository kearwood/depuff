(module
  (memory $mem 1152)
  (func $bc1_fast_compress_block (param $row0 v128)(param $row1 v128)(param $row2 v128)(param $row3 v128)(result i64)

;; Minimum palette entry, 32 bits per component
  (local $palette_min v128)

;; Maximum palette entry, 32 bits per component
  (local $palette_max v128)

  (local $palette_step v128)

;; Get maximum color
  get_local $row0
  get_local $row1
  i8x16.max_u
  get_local $row2
  i8x16.max_u
  get_local $row3
  i8x16.max_u
  tee_local $palette_max
  i16x8.widen_low_i8x16_u
  get_local $palette_max
  i16x8.widen_high_i8x16_u
  i16x8.max_u
  tee_local $palette_max
  i32x4.widen_low_i16x8_u
  get_local $palette_max
  i32x4.widen_high_i16x8_u
  i32x4.max_u
  set_local $palette_max

;; Get minimum color
  get_local $row0
  get_local $row1
  i8x16.min_u
  get_local $row2
  i8x16.min_u
  get_local $row3
  i8x16.min_u
  tee_local $palette_min
  i16x8.widen_low_i8x16_u
  get_local $palette_min
  i16x8.widen_high_i8x16_u
  i16x8.min_u
  tee_local $palette_min
  i32x4.widen_low_i16x8_u
  get_local $palette_min
  i32x4.widen_high_i16x8_u
  i32x4.min_u
  tee_local $palette_min

;; Check if any alpha values are less than 0x80

  ;; Extract the lowest alpha value

  i32x4.extract_lane 3
  i32.const 0x80
  i32.lt_u
  if
    ;; We have an alpha value of at least 0x80
    ;;
    ;; When there is alpha, our palette entries
    ;; consist of:
    ;; - Transparent
    ;; - palette_min
    ;; - palette_min * 1/2 + palette_max * 1/2
    ;; - palette_max
    ;;
    ;; When we have 3 non-transparent palette
    ;; entries, 1/4 of the total distance along
    ;; the color line is the half-way point between
    ;; the first and second palette entry
    get_local $palette_max
    get_local $palette_min
    i32x4.sub
    tee_local $palette_step
    get_local $palette_step
    i32x4.mul
    ;; We store $palette_step in fixed point notation
    ;; with the decimal at 0x100
    i32.const 0x40 ;; 0x100 / 4
    i32x4.splat
    i32x4.mul
    set_local $palette_step

    ;; We perform a dot product to determine the position of each pixel
    ;; color along a color line connecting palette_min and palette_max.
    ;; Below 1/4 along the color line, the 1st palette entry is selected.
    ;; At 1/4 along the color line, the 2nd palette entry is selected.
    ;; At 3/4 along the color line, the 3rd palette entry is selected.
  else
    ;; No alpha values less than 0x80
    ;;
    ;; When there is no alpha, our palette entries
    ;; consist of:
    ;; - palette_min
    ;; - palette_min * 2/3 + palette_max * 1/3
    ;; - palette_min * 1/3 + palette_max * 2/3
    ;; - palette_max
    ;;
    ;; When we have 4 non-transparent palette
    ;; entries, 1/6 of the total distance along
    ;; the color line is the half-way point between
    ;; the first and second palette entry
    get_local $palette_max
    get_local $palette_min
    i32x4.sub
    tee_local $palette_step
    get_local $palette_step
    i32x4.mul
    ;; We store $palette_step in fixed point notation
    ;; with the decimal at 0x100
    i32.const 0x2a ;; 0x100 / 6
    i32x4.splat
    i32x4.mul
    set_local $palette_step

    ;; We perform a dot product to determine the position of each pixel
    ;; color along a color line connecting palette_min and palette_max.
    ;; Below 1/6 along the color line, the 1st palette entry is selected.
    ;; At 1/6 along the color line, the 2nd palette entry is selected.
    ;; At 3/6 along the color line, the 3rd palette entry is selected.
    ;; At 5/6 along the color line, the 4th palette entry is selected.
  end

    i64.const 0
  )

  (func $bc1_fast_rgba (param $input_address i32)(param $output_address i32)(param $width i32)(param $height i32)(param $thread_id i32)(param $thread_count i32)(result i64)
  ;; $input_address and $output_address must be 128-bit aligned and represet byte offsets
  ;; $width and $height must be divisible by 4
  ;; $thread_id is a 0 based index
  ;; $thread_count must be at least 1
    (local $write_address i32)
    (local $block_address i32)
    (local $row_address i32)
    (local $row_index i32)
    (local $row_count i32)
    (local $column_index i32)
    (local $column_count i32)
    (local $compressed_block i64)

    ;; Convert input_address from a byte address to a 128-bit/16-byte index
    get_local $input_address
    i32.const 4
    i32.shr_u
    set_local $block_address

    ;; Convert output_address from a byte address to a 64-bit/8-byte index
    get_local $output_address
    i32.const 3
    i32.shr_u
    set_local $write_address

    get_local $width
    i32.const 2
    i32.shr_u
    set_local $column_count

    get_local $height
    i32.const 2
    i32.shr_u
    set_local $row_count

    get_local $thread_id
    set_local $row_index

      loop

      get_local 0
      set_local $column_index

      loop
        ;; Load Row 0 of Block
        get_local $block_address
        tee_local $row_address
        v128.load

        ;; Load Row 1 of Block
        get_local $row_address
        get_local $column_count
        i32.add
        tee_local $row_address
        v128.load

        ;; Load Row 2 of Block
        get_local $row_address
        get_local $column_count
        i32.add
        tee_local $row_address
        v128.load

        ;; Load Row 3 of Block
        get_local $row_address
        get_local $column_count
        i32.add
        tee_local $row_address
        v128.load

        ;; Compress the block and store the result
        ;; in $compressed_block
        call $bc1_fast_compress_block
        set_local $compressed_block

        ;; Store the compressed block in the output
        ;; buffer
        get_local $write_address
        get_local $compressed_block
        i64.store

        ;; Advance output address
        get_local $write_address
        i32.const 1
        i32.add
        set_local $write_address

        ;; Advance to next block
        get_local $block_address
        i32.const 1
        i32.add
        set_local $block_address

        ;; Advance to the next column and loop
        get_local $column_index
        i32.const 1
        i32.add
        tee_local $column_index
        get_local $column_count
        i32.lt_u
        br_if 0

      end ;; Column


      ;; Advance write address down by 4 lines for
      ;; each thread, and up 1 line to compensate for
      ;; wraparound at end of column loop
      get_local $thread_count
      i32.const 4
      i32.mul
      i32.const 1
      i32.sub
      get_local $column_count
      i32.mul
      get_local $block_address
      i32.add
      set_local $block_address

      ;; Advance to the next row and loop
      get_local $row_index
      get_local $thread_count
      i32.add
      tee_local $row_index
      get_local $row_count
      i32.lt_u
      br_if 0

    end ;; Row

    i64.const 0 ;; Debug return value
  )

  (export "bc1_fast_rgba" (func $bc1_fast_rgba))
  (export "memory" (memory $mem))
)
