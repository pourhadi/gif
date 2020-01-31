//
//  DrawingOperations.swift
//  Drawsana
//
//  Created by Steve Landey on 8/6/18.
//  Copyright © 2018 Asana. All rights reserved.
//

/**
 Add a shape to the drawing. Undoing removes the shape.
 */
struct AddShapeOperation: DrawingOperation {
  let shape: Shape

  func apply(drawing: Drawing) {
    drawing.add(shape: shape)
  }

  func revert(drawing: Drawing) {
    drawing.remove(shape: shape)
  }
}

/**
 Remove a shape from the drawing. Undoing adds the shape back.
 */
struct RemoveShapeOperation: DrawingOperation {
  let shape: Shape

  func apply(drawing: Drawing) {
    drawing.remove(shape: shape)
  }

  func revert(drawing: Drawing) {
    drawing.add(shape: shape)
  }
}

/**
 Change the transform of a `ShapeWithTransform`. Undoing sets its transform
 back to its original value.
 */
struct ChangeTransformOperation: DrawingOperation {
  let shape: ShapeWithTransform
  let transform: ShapeTransform
  let originalTransform: ShapeTransform

  init(shape: ShapeWithTransform, transform: ShapeTransform, originalTransform: ShapeTransform) {
    self.shape = shape
    self.transform = transform
    self.originalTransform = originalTransform
  }

  func apply(drawing: Drawing) {
    shape.transform = transform
    drawing.update(shape: shape)
  }

  func revert(drawing: Drawing) {
    shape.transform = originalTransform
    drawing.update(shape: shape)
  }
}

/**
 Edit the text of a `TextShape`. Undoing sets the text back to the original
 value.

 If this operation immediately follows an `AddShapeOperation` for the exact
 same text shape, and `originalText` is empty, then this operation declines to
 be added to the undo stack and instead causes the `AddShapeOperation` to simply
 add the shape with the new text value. This means that we avoid having an
 "add empty text shape" operation in the undo stack.
 */
struct EditTextOperation: DrawingOperation {
  let shape: TextShape
  let originalText: String
  let text: String

  init(
    shape: TextShape,
    originalText: String,
    text: String)
  {
    self.shape = shape
    self.originalText = originalText
    self.text = text
  }

  func shouldAdd(to operationStack: DrawingOperationStack) -> Bool {
    if originalText.isEmpty,
      let addShapeOp = operationStack.undoStack.last as? AddShapeOperation,
      addShapeOp.shape === shape
    {
      // It's pointless to let the user undo to an empty text shape. By setting
      // the shape text immediately and then declining to be added to the stack,
      // the add-shape operation ends up adding/removing the shape with the
      // correct text on its own.
      shape.text = text
      return false
    } else {
      return true
    }
  }

  func apply(drawing: Drawing) {
    shape.text = text
    drawing.update(shape: shape)
  }

  func revert(drawing: Drawing) {
    shape.text = originalText
    drawing.update(shape: shape)
  }
}

/**
 Change the user-specified width of a text shape
 */
struct ChangeExplicitWidthOperation: DrawingOperation {
  let shape: TextShape
  let originalWidth: CGFloat?
  let originalBoundingRect: CGRect
  let newWidth: CGFloat?
  let newBoundingRect: CGRect

  init(
    shape: TextShape,
    originalWidth: CGFloat?,
    originalBoundingRect: CGRect,
    newWidth: CGFloat?,
    newBoundingRect: CGRect)
  {
    self.shape = shape
    self.originalWidth = originalWidth
    self.originalBoundingRect = originalBoundingRect
    self.newWidth = newWidth
    self.newBoundingRect = newBoundingRect
  }

  func apply(drawing: Drawing) {
    shape.explicitWidth = newWidth
    shape.boundingRect = newBoundingRect
    drawing.update(shape: shape)
  }

  func revert(drawing: Drawing) {
    shape.explicitWidth = originalWidth
    shape.boundingRect = originalBoundingRect
    drawing.update(shape: shape)
  }
}

