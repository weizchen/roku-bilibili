' Minimal QR encoder for the login code: byte mode, ECC level L, versions 1-10.
' Follows the structure of Nayuki's reference generator. The login URL must not be
' handed to an online QR service: whoever polls its key receives the session.

function qrXor(a as Integer, b as Integer) as Integer
    return (a or b) - (a and b)
end function

function qrBit(x as Integer, i as Integer) as Boolean
    return ((x \ m.qrPow[i]) mod 2) = 1
end function

sub qrPushBits(bits as Object, value as Integer, count as Integer)
    for i = count - 1 to 0 step -1
        bits.Push((value \ m.qrPow[i]) mod 2)
    end for
end sub

function qrRawModules(v as Integer) as Integer
    r = (16 * v + 128) * v + 64
    if v >= 2 then
        na = v \ 7 + 2
        r = r - ((25 * na - 10) * na - 55)
        if v >= 7 then r = r - 36
    end if
    return r
end function

' ---------- GF(256) / Reed-Solomon ----------

sub qrInitGf()
    m.gfExp = CreateObject("roArray", 512, false)
    m.gfLog = CreateObject("roArray", 256, false)
    x = 1
    for i = 0 to 254
        m.gfExp[i] = x
        m.gfLog[x] = i
        x = x * 2
        if x >= 256 then x = qrXor(x, &h11D)
    end for
    for i = 255 to 511
        m.gfExp[i] = m.gfExp[i - 255]
    end for
end sub

function qrMul(a as Integer, b as Integer) as Integer
    if a = 0 or b = 0 then return 0
    return m.gfExp[m.gfLog[a] + m.gfLog[b]]
end function

function qrDivisor(degree as Integer) as Object
    result = []
    for i = 0 to degree - 2
        result.Push(0)
    end for
    result.Push(1)
    root = 1
    for k = 0 to degree - 1
        for j = 0 to degree - 1
            result[j] = qrMul(result[j], root)
            if j + 1 < degree then result[j] = qrXor(result[j], result[j + 1])
        end for
        root = qrMul(root, 2)
    end for
    return result
end function

function qrRemainder(data as Object, divisor as Object) as Object
    n = divisor.Count()
    result = []
    for i = 0 to n - 1
        result.Push(0)
    end for
    for each b in data
        factor = qrXor(b, result.Shift())
        result.Push(0)
        for i = 0 to n - 1
            result[i] = qrXor(result[i], qrMul(divisor[i], factor))
        end for
    end for
    return result
end function

' ---------- matrix ----------

sub qrSetFn(x as Integer, y as Integer, dark as Boolean)
    if dark then
        m.qrMods[y][x] = 1
    else
        m.qrMods[y][x] = 0
    end if
    m.qrFn[y][x] = true
end sub

sub qrFinder(cx as Integer, cy as Integer)
    for dy = -4 to 4
        for dx = -4 to 4
            d = Abs(dx)
            if Abs(dy) > d then d = Abs(dy)
            xx = cx + dx
            yy = cy + dy
            if xx >= 0 and xx < m.qrSize and yy >= 0 and yy < m.qrSize then qrSetFn(xx, yy, d <> 2 and d <> 4)
        end for
    end for
end sub

sub qrAlign(cx as Integer, cy as Integer)
    for dy = -2 to 2
        for dx = -2 to 2
            d = Abs(dx)
            if Abs(dy) > d then d = Abs(dy)
            qrSetFn(cx + dx, cy + dy, d <> 1)
        end for
    end for
end sub

sub qrFormat(mask as Integer)
    dat = 8 + mask   ' ECC level L has format bits 01
    r = dat
    for i = 0 to 9
        r = qrXor(r * 2, (r \ 512) * &h537)
    end for
    bits = qrXor(dat * 1024 + r, &h5412)
    size = m.qrSize
    for i = 0 to 5
        qrSetFn(8, i, qrBit(bits, i))
    end for
    qrSetFn(8, 7, qrBit(bits, 6))
    qrSetFn(8, 8, qrBit(bits, 7))
    qrSetFn(7, 8, qrBit(bits, 8))
    for i = 9 to 14
        qrSetFn(14 - i, 8, qrBit(bits, i))
    end for
    for i = 0 to 7
        qrSetFn(size - 1 - i, 8, qrBit(bits, i))
    end for
    for i = 8 to 14
        qrSetFn(8, size - 15 + i, qrBit(bits, i))
    end for
    qrSetFn(8, size - 8, true)
end sub

sub qrVersionBits(ver as Integer)
    r = ver
    for i = 0 to 11
        r = qrXor(r * 2, (r \ 2048) * &h1F25)
    end for
    bits = ver * 4096 + r
    for i = 0 to 17
        b = qrBit(bits, i)
        a = m.qrSize - 11 + i mod 3
        c = i \ 3
        qrSetFn(a, c, b)
        qrSetFn(c, a, b)
    end for
end sub

function qrMaskBit(mask as Integer, x as Integer, y as Integer) as Boolean
    if mask = 0 then return (x + y) mod 2 = 0
    if mask = 1 then return y mod 2 = 0
    if mask = 2 then return x mod 3 = 0
    if mask = 3 then return (x + y) mod 3 = 0
    if mask = 4 then return (x \ 3 + y \ 2) mod 2 = 0
    if mask = 5 then return (x * y) mod 2 + (x * y) mod 3 = 0
    if mask = 6 then return ((x * y) mod 2 + (x * y) mod 3) mod 2 = 0
    return ((x + y) mod 2 + (x * y) mod 3) mod 2 = 0
end function

sub qrApplyMask(mask as Integer)
    size = m.qrSize
    for y = 0 to size - 1
        row = m.qrMods[y]
        fnRow = m.qrFn[y]
        for x = 0 to size - 1
            if not fnRow[x] then
                if qrMaskBit(mask, x, y) then row[x] = 1 - row[x]
            end if
        end for
    end for
end sub

function qrCountPattern(s as String, pattern as String) as Integer
    n = 0
    i = Instr(1, s, pattern)
    while i > 0
        n = n + 1
        i = Instr(i + 1, s, pattern)
    end while
    return n
end function

' ISO 18004 penalty, used to pick the most scanner-friendly mask.
function qrPenalty() as Integer
    size = m.qrSize
    mods = m.qrMods
    p = 0
    dark = 0
    cols = []
    for x = 0 to size - 1
        cols.Push("")
    end for
    for y = 0 to size - 1
        row = mods[y]
        runLen = 1
        rowStr = ""
        for x = 0 to size - 1
            v = row[x]
            dark = dark + v
            rowStr = rowStr + v.ToStr()
            cols[x] = cols[x] + v.ToStr()
            if x > 0 then
                if v = row[x - 1] then
                    runLen = runLen + 1
                else
                    if runLen >= 5 then p = p + runLen - 2
                    runLen = 1
                end if
            end if
            if y < size - 1 and x < size - 1 then
                if v = row[x + 1] and v = mods[y + 1][x] and v = mods[y + 1][x + 1] then p = p + 3
            end if
        end for
        if runLen >= 5 then p = p + runLen - 2
        p = p + 40 * (qrCountPattern(rowStr, "10111010000") + qrCountPattern(rowStr, "00001011101"))
    end for
    for each col in cols
        runLen = 1
        for i = 2 to size
            if Mid(col, i, 1) = Mid(col, i - 1, 1) then
                runLen = runLen + 1
            else
                if runLen >= 5 then p = p + runLen - 2
                runLen = 1
            end if
        end for
        if runLen >= 5 then p = p + runLen - 2
        p = p + 40 * (qrCountPattern(col, "10111010000") + qrCountPattern(col, "00001011101"))
    end for
    total = size * size
    k = (Int(Abs(dark * 20 - total * 10)) + total - 1) \ total - 1
    return p + k * 10
end function

' -> { size, rows: ["0101...", ...] } or invalid if the text is too long
function qrEncode(text as String) as Dynamic
    m.qrPow = []
    v = 1
    for i = 0 to 20
        m.qrPow.Push(v)
        v = v * 2
    end for
    qrInitGf()

    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(text)
    n = bytes.Count()
    eccPerBlock = [0, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18]
    numBlocks = [0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4]
    ver = 0
    for v = 1 to 10
        ccBits = 8
        if v >= 10 then ccBits = 16
        cap = (qrRawModules(v) \ 8 - eccPerBlock[v] * numBlocks[v]) * 8
        if 4 + ccBits + n * 8 <= cap then
            ver = v
            exit for
        end if
    end for
    if ver = 0 then return invalid
    ccBits = 8
    if ver >= 10 then ccBits = 16
    rawCw = qrRawModules(ver) \ 8
    eccLen = eccPerBlock[ver]
    nb = numBlocks[ver]
    capBits = (rawCw - eccLen * nb) * 8

    ' data bits: byte mode, length, payload, terminator, pad
    bits = []
    qrPushBits(bits, 4, 4)
    qrPushBits(bits, n, ccBits)
    for i = 0 to n - 1
        qrPushBits(bits, bytes[i], 8)
    end for
    term = capBits - bits.Count()
    if term > 4 then term = 4
    qrPushBits(bits, 0, term)
    while bits.Count() mod 8 <> 0
        bits.Push(0)
    end while
    pad = &hEC
    while bits.Count() < capBits
        qrPushBits(bits, pad, 8)
        if pad = &hEC then pad = &h11 else pad = &hEC
    end while
    data = []
    for i = 0 to bits.Count() - 1 step 8
        b = 0
        for j = 0 to 7
            b = b * 2 + bits[i + j]
        end for
        data.Push(b)
    end for

    ' blocks + error correction, then interleave
    numShort = nb - rawCw mod nb
    shortLen = rawCw \ nb
    divisor = qrDivisor(eccLen)
    blocks = []
    k = 0
    for i = 0 to nb - 1
        dl = shortLen - eccLen
        if i >= numShort then dl = dl + 1
        dat = []
        for j = 0 to dl - 1
            dat.Push(data[k + j])
        end for
        k = k + dl
        ecc = qrRemainder(dat, divisor)
        if i < numShort then dat.Push(0)
        dat.Append(ecc)
        blocks.Push(dat)
    end for
    codewords = []
    for i = 0 to blocks[0].Count() - 1
        for j = 0 to nb - 1
            if i <> shortLen - eccLen or j >= numShort then codewords.Push(blocks[j][i])
        end for
    end for

    ' function patterns
    size = ver * 4 + 17
    m.qrSize = size
    m.qrMods = []
    m.qrFn = []
    for y = 0 to size - 1
        r1 = CreateObject("roArray", size, false)
        r2 = CreateObject("roArray", size, false)
        for x = 0 to size - 1
            r1[x] = 0
            r2[x] = false
        end for
        m.qrMods.Push(r1)
        m.qrFn.Push(r2)
    end for
    for i = 0 to size - 1
        qrSetFn(6, i, (i mod 2) = 0)
        qrSetFn(i, 6, (i mod 2) = 0)
    end for
    qrFinder(3, 3)
    qrFinder(size - 4, 3)
    qrFinder(3, size - 4)
    if ver >= 2 then
        na = ver \ 7 + 2
        gap = (ver * 8 + na * 3 + 5) \ (na * 4 - 4) * 2
        apos = [6]
        for i = na - 2 to 0 step -1
            apos.Push(size - 7 - i * gap)
        end for
        cnt = apos.Count()
        for i = 0 to cnt - 1
            for j = 0 to cnt - 1
                corner = (i = 0 and j = 0) or (i = 0 and j = cnt - 1) or (i = cnt - 1 and j = 0)
                if not corner then qrAlign(apos[i], apos[j])
            end for
        end for
    end if
    qrFormat(0)
    if ver >= 7 then qrVersionBits(ver)

    ' codewords in the zigzag
    i = 0
    total = codewords.Count() * 8
    colRight = size - 1
    while colRight >= 1
        if colRight = 6 then colRight = 5
        for vert = 0 to size - 1
            for j = 0 to 1
                x = colRight - j
                if ((colRight + 1) and 2) = 0 then
                    y = size - 1 - vert
                else
                    y = vert
                end if
                if not m.qrFn[y][x] and i < total then
                    cw = codewords[i \ 8]
                    m.qrMods[y][x] = (cw \ m.qrPow[7 - (i mod 8)]) mod 2
                    i = i + 1
                end if
            end for
        end for
        colRight = colRight - 2
    end while

    ' pick the mask with the lowest penalty
    bestMask = 0
    bestScore = -1
    for mask = 0 to 7
        qrApplyMask(mask)
        qrFormat(mask)
        score = qrPenalty()
        if bestScore < 0 or score < bestScore then
            bestScore = score
            bestMask = mask
        end if
        qrApplyMask(mask)
    end for
    qrApplyMask(bestMask)
    qrFormat(bestMask)

    rows = []
    for y = 0 to size - 1
        s = ""
        for x = 0 to size - 1
            s = s + m.qrMods[y][x].ToStr()
        end for
        rows.Push(s)
    end for
    return { size: size, version: ver, mask: bestMask, rows: rows }
end function
