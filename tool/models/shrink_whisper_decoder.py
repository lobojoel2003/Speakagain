"""Shrink a sherpa-onnx Whisper decoder by storing its token embedding as 8-bit.

sherpa-onnx's int8 Whisper decoders quantize the matrix multiplications but keep
the token embedding (51,865 x d_model) in 32-bit floats, which is most of the
file (106 MB of the 131 MB base decoder). This stores it as uint8 with one scale
per row and rewrites the two places it is used:

- the embedding lookup: Gather(uint8) -> Cast -> subtract 128 -> multiply by the row scale
- the output projection (logits = W @ x^T): DynamicQuantizeLinear(x) -> MatMulInteger

The graph's inputs and outputs are unchanged, so sherpa-onnx loads it as usual.
Whisper base: 131 MB -> 51 MB, tiny: 90 MB -> 31 MB, with the same transcripts in
our checks (tool/models/README.md).

Usage: python shrink_whisper_decoder.py <decoder.int8.onnx> <output.onnx>
"""

import sys

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

EMBEDDING = 'textDecoder.token_embedding.weight'


def shrink(src: str, dst: str) -> None:
    model = onnx.load(src)
    graph = model.graph
    init = next(i for i in graph.initializer if i.name == EMBEDDING)
    weights = numpy_helper.to_array(init).astype(np.float32)
    scale = np.maximum(np.abs(weights).max(axis=1, keepdims=True), 1e-8) / 127.0
    quantized = (np.clip(np.round(weights / scale), -127, 127) + 128).astype(np.uint8)

    graph.initializer.remove(init)
    graph.initializer.extend([
        numpy_helper.from_array(quantized, EMBEDDING + '_q'),
        numpy_helper.from_array(scale.astype(np.float32), EMBEDDING + '_scale'),
        numpy_helper.from_array(scale.reshape(-1).astype(np.float32), EMBEDDING + '_scale_vec'),
        numpy_helper.from_array(np.array(128, dtype=np.uint8), EMBEDDING + '_zp'),
        numpy_helper.from_array(np.array(128.0, dtype=np.float32), EMBEDDING + '_zpf'),
        numpy_helper.from_array(np.array([-1], dtype=np.int64), EMBEDDING + '_axes_m1'),
    ])

    identity_out = None
    kept = []
    for node in graph.node:
        if node.op_type == 'Identity' and node.input[0] == EMBEDDING:
            identity_out = node.output[0]
            continue
        kept.append(node)
    if identity_out is None:
        raise SystemExit('Unexpected decoder graph: no Identity on the token embedding')

    rewritten = []
    gathers = matmuls = 0
    for node in kept:
        if node.op_type == 'Gather' and node.input[0] == EMBEDDING:
            idx, out = node.input[1], node.output[0]
            rewritten += [
                helper.make_node('Gather', [EMBEDDING + '_q', idx], [out + '_q'], axis=0),
                helper.make_node('Cast', [out + '_q'], [out + '_qc'], to=TensorProto.FLOAT),
                helper.make_node('Sub', [out + '_qc', EMBEDDING + '_zpf'], [out + '_qf']),
                helper.make_node('Gather', [EMBEDDING + '_scale_vec', idx], [out + '_s'], axis=0),
                helper.make_node('Unsqueeze', [out + '_s', EMBEDDING + '_axes_m1'], [out + '_s1']),
                helper.make_node('Mul', [out + '_qf', out + '_s1'], [out]),
            ]
            gathers += 1
            continue
        if node.op_type == 'MatMul' and node.input[0] == identity_out:
            x, out = node.input[1], node.output[0]
            rewritten += [
                helper.make_node('DynamicQuantizeLinear', [x], [x + '_q', x + '_qs', x + '_qzp']),
                helper.make_node('MatMulInteger', [EMBEDDING + '_q', x + '_q', EMBEDDING + '_zp', x + '_qzp'], [out + '_i32']),
                helper.make_node('Cast', [out + '_i32'], [out + '_f'], to=TensorProto.FLOAT),
                helper.make_node('Mul', [EMBEDDING + '_scale', x + '_qs'], [out + '_ws']),
                helper.make_node('Mul', [out + '_f', out + '_ws'], [out]),
            ]
            matmuls += 1
            continue
        rewritten.append(node)
    if gathers != 1 or matmuls != 1:
        raise SystemExit(f'Unexpected decoder graph: {gathers} embedding lookups, {matmuls} projections')

    del graph.node[:]
    graph.node.extend(rewritten)
    onnx.checker.check_model(model)
    onnx.save(model, dst)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    shrink(sys.argv[1], sys.argv[2])
